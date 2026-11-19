# Epic 06 Learnings -- Subproblem Structure and Stochastic Improvements

## Patterns Established

### Always-2D Block Variables

All power and flow decision variables are now permanently 2D `[entity, block]`, even for the single-block case. The decision to always use 2D (rather than branching between 1D and 2D based on num_blocks) eliminates conditional paths throughout the entire build pipeline. Single-block backward compatibility is automatic: `num_blocks == 1` produces `[entity, 1]`, which is functionally identical to `[entity]` but without branching logic. See `src/Engines/sddp/build.jl` lines 46-216.

### State Variables Remain 1D

`STORED_VOLUME` (hydro storage) and inflow variables (`INFLOW`, `omega_INFLOW`, `STCHP`) are 1D regardless of block count. The rule is: SDDP state variables (cut generation) must remain stage-level; all other hydraulic variables are block-indexed. Intermediate block storage for chronological mode (`BLOCK_STORAGE`) is a regular JuMP variable, NOT an SDDP.State. This is essential for correct dual value computation in cut generation. See `src/Engines/sddp/build.jl` lines 141-197.

### BlockConfig as Scenarios Field

Block configuration lives on `ScenariosData` as a required field `block_config::BlockConfig`, never as a `Union{BlockConfig,Nothing}`. When the user omits `"blocks"` from the JSON, `default_block_config()` provides an empty-block config that degenerates to single-block behavior at build time. The sentinel value is an empty `blocks` vector (not `nothing`), checked via `has_blocks(bc)`. See `src/Scenarios/blocks.jl` and `src/Scenarios/Scenarios.jl` line 51.

### Tau/Zeta Computed Inside the Closure, Not Stored

Stage duration `tau` and flow conversion `zeta` are computed per-node inside `fun_sp_build` from a precomputed `node_datetimes::Dict{Int,Tuple{DateTime,DateTime}}`. This means `tau_k` (per-block durations) varies per node even when the BlockConfig is constant. The `get_block_durations(block_config, tau)` helper returns `[tau]` for the default case and `[b.duration_hours for b in bc.blocks]` otherwise. See `src/Engines/sddp/build.jl` lines 786-819.

### InflowNonNegativity as a 5th SDDPEngine Field

The engine struct grew from 4 to 5 fields with the addition of `inflow_non_negativity::InflowNonNegativity`. The new field is parsed under an optional `"modeling"` key in the engine JSON, defaulting to `InflowNone()` when absent. This extends the engine without breaking existing configs. The pattern for future modeling options: add to the `"modeling"` sub-dict and extend `__build_inflow_non_negativity!` in `src/Engines/input.jl`.

### Penalty Expression via Multiple Dispatch on InflowNonNegativity

The inflow penalty contribution to the objective is computed by `_inflow_penalty_expr(m, method, tau_k, scaling)`, which dispatches on the method type and returns `0.0` for `InflowNone`/`InflowTruncation`, and a JuMP expression for penalty-bearing methods. This avoids `if/else` chains in `add_system_objective!` and makes it trivial to add new inflow methods. See `src/Engines/sddp/build.jl` lines 404-454.

### Sigma Values Stored in JuMP Model Ext Dict

For `InflowTruncationWithPenalty`, the AR residual standard deviation `sigma_m` (per hydro) is needed at objective construction time but is only available inside `add_inflow_uncertainty!`. Rather than threading sigma through function signatures, it is stored in `m.ext[:noise_adjustment_sigma]` by `add_inflow_uncertainty!` and read by `_inflow_penalty_expr`. See `src/Engines/sddp/build.jl` lines 569, 444.

### Objective Structure: Sum Over Blocks Wrapping All Cost Terms

The `SDDP.@stageobjective` now has an outer `sum(... for k in 1:K)` wrapping all per-block cost terms, each pre-multiplied by `tau_k[k]`. The inflow penalty (which is per-stage, not per-block) is added outside this sum. This structure correctly degenerates to the pre-block form when K=1. See `src/Engines/sddp/build.jl` lines 479-495.

## Architectural Decisions

### Decision: Always-2D Variables (Rejected: Conditional 1D/2D)

The rejected alternative was branching: use 1D variables when K=1, 2D when K>1. This was rejected because it would require conditional paths in every constraint and output processing function. The cost is one extra dimension in the single-block case (effectively free in JuMP). The benefit is completely uniform code with no branching anywhere in the build pipeline.

### Decision: Parallel Mode Uses Weighted Flow Sum, Not Per-Block Balance

Parallel mode collapses all K blocks into a single water balance using block weights `w_k = tau_k / sum(tau_k)`. Chronological mode creates K per-block balances with intermediate storage variables. The choice between modes is made at config time via `block_mode::Symbol` on `BlockConfig`, dispatched in `add_hydro_balance!`. Rationale: parallel mode preserves the existing 1-constraint-per-hydro structure, keeping LP dimensions manageable for common use cases.

### Decision: Inflow Truncation Is SAA-Side Only

`InflowTruncation` clips the noise vector (`max.(0.0, omega)`) in the SAA before the subproblem builder closure, not as an LP constraint. This was chosen over adding `INFLOW >= 0` as a hard bound because a hard lower bound on INFLOW conflicts with `JuMP.fix` in the parameterize callback (fixing a variable to a value outside its bound makes the LP infeasible). The SAA-only truncation does not guarantee non-negative inflows (because lag contributions can still make the AR output negative), which is documented as a limitation. `InflowPenalty` and `InflowTruncationWithPenalty` are the guaranteed methods. See `src/Engines/sddp/build.jl` lines 754-759.

### Decision: Block Names Stored as Strings in Load Data (Not Block Index)

Load data was extended to carry an optional `block_name::String` field on `DeterministicLoadValue`. Lookup in `get_load(bus_id, node_id, block_idx, scenarios)` converts the integer block index to a block name via `bc.blocks[block_idx].name` and then queries by name. This preserves the semantic identity of blocks (by name) independent of their position index. See `src/Scenarios/load.jl` lines 4-77 and `src/Scenarios/Scenarios.jl` lines 66-76.

### Decision: BlockConfig Parsing Uses Direct Validator Functions, Not FieldRule Schema

Block definitions required validation of a nested vector of dicts (variable length, cross-item uniqueness checks). The FieldRule schema system handles flat scalar fields well but not variable-length nested structures. Custom validator functions `__validate_block_mode!` and `__validate_block_definitions!` were written directly, consistent with the prior pattern for complex nested structures. See `src/Scenarios/blocks.jl` lines 79-159.

## Files and Structures Created

- `src/Scenarios/blocks.jl` -- `Block` struct, `BlockConfig` struct, all helper functions (`has_blocks`, `num_blocks`, `get_block_names`, `get_block_durations`, `get_block_weights`), and `BlockConfig(d, e)` constructor with validators. This is a new file created for the epic.
- `src/Engines/Engines.jl` -- Added `InflowNonNegativity` abstract type and 4 concrete subtypes (`InflowNone`, `InflowPenalty`, `InflowTruncation`, `InflowTruncationWithPenalty`), and `inflow_non_negativity` as the 5th field of `SDDPEngine`.
- `test/test-stage-duration.jl` -- Unit tests for tau/zeta computation and the end-to-end 1dtoy pipeline with time-duration-aware costs.
- `test/test-load-blocks.jl` -- Unit tests for BlockConfig parsing/validation, 2D variable dimensions, per-block load balance, parallel and chronological water balances, and e2e parallel/chronological block builds.
- `test/test-inflow-nonnegativity.jl` -- Unit tests for config parsing of all 4 inflow methods, LP structure verification (variable presence, lower bounds), and e2e tests with Naive and AR processes.

## Conventions Adopted

### `UNCERTAINTIES_KEYS` Extended for `block_config`

The scenarios data schema key list in `src/Scenarios/scenariosdata-validators.jl` line 11 was extended to include `"block_config"`. However, `"blocks"` (the user-facing JSON key) is NOT in `CONFIGURATION_KEYS` -- it is an optional key handled by `__build_block_config!` using `haskey(d, "blocks")`. The resolved `block_config` object is injected into the dict under the key `"block_config"` before schema validation runs. This follows the same pattern established for optional system entities in Epic 05.

### `no_scaling_config()` Includes New Symbols

Any new variable symbol added to `Lab/variables.jl` must also be added to `no_scaling_config()` in `src/Engines/sddp/scaling.jl`. In this epic, `INFLOW_SLACK` and `NOISE_ADJUSTMENT_SLACK` were added at lines 98-99. Missing symbols in `no_scaling_config()` cause `KeyError` when `_get_variable_unscale_factor` falls through to the `else` branch.

### Optional Variable Existence Check Before Output

`save_simulation.jl` now includes `__variable_exists_in_sim(simulations, variable)` checks before processing any variable. This is required for variables that only exist when a non-default method is active (e.g., `INFLOW_SLACK` is absent when `InflowNone` is used). The check probes the first stage dict across all simulations. See `src/Engines/sddp/save_simulation.jl` lines 123-134 and 276-278.

### 2D Variable Detection in Output via `__is_2d_variable`

The simulation output writer detects whether a variable is 1D or 2D by inspecting whether its value is `AbstractMatrix`. Block dimension is extracted via `__get_num_blocks_from_sim`. Block-indexed outputs append `_B1`, `_B2`, ... to the variable name in CSV output. See `src/Engines/sddp/save_simulation.jl` lines 142-175 and 195-196.

### Water Balance Unified Dispatch

`add_hydro_balance!` is the single public entry point, routing to `add_hydro_balance_parallel!` or `add_hydro_balance_chronological!` based on `block_mode::Symbol`. Tests call the specific functions directly for unit testing and the unified dispatch for integration testing. This follows the same convention as `add_system_elements!` dispatching on entity type.

## Surprises and Deviations

### Ticket-028 Was Absorbed Into Ticket-029 Without Separate Commit

The plan anticipated ticket-028 (single-block tau/zeta) as a standalone intermediate state before ticket-029 (multi-block). In practice, the implementation jumped directly to the always-2D formulation. The single-block case is handled by `K=1` in the 2D path, so a distinct single-block phase never existed in the codebase. This is a better outcome (simpler code) but means the "ticket-028 intermediate state" described in the tickets does not exist in git history.

### `JuMP.fix` and Lower Bounds Conflict Is Real

The ticket notes warned: "INFLOW is set by `JuMP.fix` in parameterize; a lower bound conflicts with fix." This conflict was confirmed and is the primary reason `InflowTruncation` is SAA-side only. Specifically, `JuMP.fix(m[omega_INFLOW][n], omega)` sets an equality constraint; if `omega < 0` and `INFLOW >= 0` is also set, the LP becomes infeasible. The `InflowPenalty` approach avoids this by decoupling `INFLOW` (which gets the lower bound) from `STCHP.out` (which is unconstrained) via the `INFLOW_SLACK` variable.

### Block Duration Validation Gap: Sum Check Not Implemented

The ticket-029 specification required validating that the sum of block durations equals the stage duration. This was NOT implemented -- there is no such check in `__validate_block_definitions!` or in `add_hydro_balance!`. The reason: stage duration is only known at model build time (it varies per graph node), while block durations are parsed at scenarios-load time. Enforcing the constraint would require threading graph node datetimes into the block validation pipeline. This is a known limitation documented implicitly by the absence of the validation.

### `INFLOW_PENALTY_SCHEMA` Reused for Both Penalty Types

Both `InflowPenalty` and `InflowTruncationWithPenalty` share the same schema constant `INFLOW_PENALTY_SCHEMA` in `src/Engines/input-validators.jl`. This works because both have a single `penalty_cost` field with a `positive()` constraint. If either type gains additional fields, the schema must be split.

### Intermediate Block Storage Not Exposed in Save Output

`BLOCK_STORAGE` (the intermediate storage variables in chronological mode) is NOT included in `map_variable_output` or `map_variable_entities` in `save_simulation.jl`. This means intermediate storage values are not written to CSV output files. This was an intentional omission (intermediate volumes are primarily debugging artifacts, not operational outputs), but future epics may need to add this if users want to inspect within-stage storage dynamics.

## Recommendations for Future Epics

- The `__add_load_balance!` function in `src/Engines/sddp/build.jl` now has 14 parameters. Any epic that adds another entity type with a bus assignment will push this to 15+. Refactor to a context struct (e.g., `LoadBalanceContext`) before or during that addition.
- The `SDDPEngine` 5th field `inflow_non_negativity` established the pattern for embedding modeling options. Future modeling options (e.g., water evaporation, thermal startup costs) should follow the same pattern: add to the `"modeling"` sub-dict, add a `__build_OPTION!` function in `src/Engines/input.jl`, add the type hierarchy to `src/Engines/Engines.jl`, and pass the option through `__generate_subproblem_builder`.
- The `JuMP.fix` / lower-bound conflict is a general constraint: any new variable that is set via `SDDP.parameterize` (e.g., future stochastic demand) cannot simultaneously carry a hard bound. Use a slack variable pattern if both a hard bound and stochastic parameterization are needed.
- Block duration sum validation (sum of block hours = stage hours) is currently unimplemented. If strict physical consistency is required, the validation must be deferred to `__generate_subproblem_builder` where `tau` is available, and should emit an error accumulated into a new `CompositeException` that propagates to the `Lab.build` caller.
- The `m.ext` dict (used to store `noise_adjustment_sigma`) is an escape hatch for passing data between `add_inflow_uncertainty!` and `_inflow_penalty_expr`. It works but is untyped. If more data needs to flow between builder functions, consider a typed builder context struct to replace ad-hoc `ext` usage.
- Future epics adding new system entities must extend `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, and `map_variable_entities` -- six touch points across `scaling.jl` and `save_simulation.jl`. Consider a registration table to reduce the chance of missing one.
