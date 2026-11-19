# Accumulated Learnings Summary -- Epic 07

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures; `AssertionError` for semantic violations; errors accumulate, never thrown
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)
- `SystemData` always has all fields as required; empty sets represent absent entity types; backward compat via `haskey` guards in the parser
- Abstract sentinel type is the default for optional engine fields (e.g., `NoMarkovChain`/`MarkovChainConfig`, `InflowNone`/`InflowPenalty`); `Union{T, Nothing}` is reserved for fields where absence should error, documented in `src/Engines/Engines.jl` line 233 (`validation` field)

## Optional Entity and Config Pattern

- New fields on `SystemData` or `ScenariosData` are never `Union{T,Nothing}`; always required with empty/default values
- Backward compat: `haskey(d, "key")` in internals builder creates defaults when key is absent; resolved object is injected into dict before schema validation
- Every `add_system_elements!(m, ses::NewType)` begins with `if length(ses) == 0; return nothing; end`
- New in Epic 07: `ScenariosData` gained 8th field `markov_chain::AbstractMarkovChain`; defaults to `NoMarkovChain()` when absent

## Block Variable Dimensionality (Epic 06)

- All power and flow decision variables are permanently 2D `[entity, block]` even for K=1; no branching between 1D and 2D (`src/Engines/sddp/build.jl` lines 46-216)
- State variables (`STORED_VOLUME`) and inflow variables (`INFLOW`, `omega_INFLOW`, `STCHP`) are always 1D -- SDDP cut generation requires stage-level state
- `BLOCK_STORAGE` (chronological mode intermediate volumes) is a regular JuMP variable, NOT `SDDP.State`; making it a state variable breaks dual values and cut generation
- `BlockConfig` lives on `ScenariosData` as a required field; `default_block_config()` returns empty blocks; `has_blocks(bc)` distinguishes configured vs. default (`src/Scenarios/blocks.jl`)

## Modeling Options Pattern (Epics 06-07)

- `SDDPEngine` has 6 fields as of Epic 07; 5th is `inflow_non_negativity::InflowNonNegativity`; 6th is `validation::Union{OutOfSampleValidation,Nothing}`
- Parsed under optional JSON keys: `"modeling"` for inflow non-negativity; `"validation"` for OOS validation
- Future modeling options: add to `"modeling"` sub-dict, add `__build_OPTION!` in `src/Engines/input.jl`, add type hierarchy to `src/Engines/Engines.jl`, pass through `__generate_subproblem_builder`
- Multiple dispatch on method type for objective contribution: `_inflow_penalty_expr(m, method, tau_k, scaling)` returns `0.0` for non-penalty methods; avoids if/else chains (`src/Engines/sddp/build.jl` lines 340-385)

## Stochastic Process Architecture (Epics 01-07)

- All processes implement `AbstractStochasticProcess`; auto-resolved via `__kind_factory!` from `{"kind": "TypeName", "params": {...}}` -- no registration needed
- Three process types: `Naive` (copula marginals), `AutoRegressive` (univariate PAR(p) per element), `VectorAutoRegressive` (multivariate VAR(p) with N x N coefficient matrices)
- `VectorAutoRegressive` struct holds `Dict{Int,VARSeasonParameters}` (season -> matrices+scales), a `Naive` noise model, element IDs, initial values, and max lag (`src/StochasticProcess/vectorautoregressive.jl`)
- VAR STCHP flat indexing: `index_t[n] = (n-1) * max_lag + 1`; memory shift states = all indices not in `index_t`; recurrence in normalized `(X-mu)/sigma` space (`src/Engines/sddp/build.jl` lines 562-692)
- `__build_var_noise_naive_dict` transforms VAR params dict into Naive-compatible format; reuses `Naive` constructor for noise model -- no duplication (`src/StochasticProcess/vectorautoregressive.jl` lines 108-127)
- VAR coefficient matrices operate in normalized space: `Phi[n,m]` is dimensionless, coupling hydro m's normalized lag to hydro n's normalized current value

## Markov Chain Architecture (Epic 07)

- `AbstractMarkovChain` / `NoMarkovChain` / `MarkovChainConfig` in `src/Scenarios/markov.jl`; dispatch via `has_markov_chain`, `num_markov_states`
- `InflowScenarios.stochastic_process` is now `Dict{Int, AbstractStochasticProcess}`; legacy JSONs wrapped in `Dict(1 => process)` at parse time (`src/Scenarios/inflow-validators.jl`)
- `__is_multi_process_dict` detects Markov format by absence of "kind"/"params" keys; string-integer keys parsed to `Int` via `tryparse`
- When Markov active: `__build_graph` returns `SDDP.MarkovianGraph(mc.transition_matrices)`; bypasses SDDPlab `Graph` entirely; stage count still from `scenarios.graph.nodes`
- Node type helpers `__extract_stage` / `__extract_markov_state` dispatch over `Integer` (legacy) and `Tuple{Int,Int}` (Markov); used uniformly in `__generate_subproblem_builder` and `Lab.validate` (`src/Engines/sddp/build.jl` lines 803-825)
- `stage_datetimes` map (keyed by `n.stage`) added alongside `node_datetimes`; Markov subproblems index datetimes by stage, load by `stage_to_node_id[stage]`
- Per-state SAA uses prime offset: `seed + (state - 1) * 7919` for independence across Markov states
- `__validate_transition_matrices!` converts JSON arrays to `Vector{Matrix{Float64}}` in-place before construction; first matrix must have 1 row; rows must sum to 1.0 within 1e-6

## Out-of-Sample Validation (Epic 07)

- `OutOfSampleValidation` struct (4 fields: `num_simulations`, `seed`, `branchings`, `parallel_scheme`) is the 6th field on `SDDPEngine` as `Union{T, Nothing}` -- sole `Union` exception in the engine (`src/Engines/Engines.jl` lines 214-233)
- `Lab.validate` in `src/Engines/sddp/validate.jl`: generates OOS SAA, applies scaling, always truncates to non-negative (known limitation: should condition on inflow method), builds `SDDP.OutOfSampleMonteCarlo` with `use_insample_transition=true`, runs `SDDP.simulate`, computes statistics
- `_compute_validation_statistics` uses Julia stdlib `Statistics` only; `_t_quantile_95(df)` is an inline lookup table (no `Distributions.jl` dependency); returns 10 metrics including CI bounds, percentiles, max/min
- Output uses `validation_` prefix on all file names; `__write_validation_statistics` writes a `(metric_name, value)` DataFrame; logic in `save_validation.jl` mirrors `save_simulation.jl` structure
- `SDDP.add_all_cuts(model.policy_graph)` called before sampler construction to ensure all training cuts are available

## JuMP.fix and Lower Bound Conflict (Epic 06)

- Variables set via `SDDP.parameterize` with `JuMP.fix` cannot simultaneously carry hard lower bounds; fixing outside the bound causes LP infeasibility
- `InflowTruncation` is SAA-side only (`max.(0.0, omega)`) and does NOT guarantee non-negative inflows
- For guaranteed non-negativity: use `InflowPenalty` or `InflowTruncationWithPenalty`

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`; predicates: `positive()`, `non_negative()`, `in_range`, `matches`, etc.
- Handles ~80% of boilerplate for flat scalar fields; nested dicts and variable-length vectors require custom validators

## Bus Index Map and Load Balance

- `_build_bus_index_map(entities, ids, field::Symbol)` maps any `ids` vector to entity positions via any field; 10 maps precomputed in `__generate_subproblem_builder`
- `__add_load_balance!` now has 14 parameters; refactor threshold is 15+ -- approaching limit; refactor to context struct before next entity type

## Scaling System

- `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, `map_variable_entities` are six touch points for every new variable symbol
- `no_scaling_config()` must include every new symbol; missing symbols cause `KeyError` at simulation output time
- Validation output maps in `validate.jl` are a **separate copy** of the simulation output maps -- must be updated in both locations when adding new entity types

## Simulation Output

- `__variable_exists_in_sim(simulations, variable)` must be called before processing optional variables
- `__is_2d_variable` detects `AbstractMatrix`; block-indexed outputs append `_B1`, `_B2`, ...
- Validation output follows same pattern with `validation_` prefix; same `_unscale_simulations` function reused

## Algorithm Option Type System

- Ten abstract type dimensions: `StoppingCriteria`, `ParallelScheme`, `RiskMeasure`, `SamplingScheme`, `DualityHandler`, `ForwardPassStrategy`, `CutType`, `ScalingMode`, `InflowNonNegativity`, `AbstractMarkovChain` (added Epic 07)
- Parameterless subtypes: `Type(::Dict, ::CompositeException) = Type()`; parameter-bearing subtypes: schema-validated constructors

## Testing Conventions

- Always create new test files; never add to large existing files (SIGABRTs observed)
- Never run `test-main` without 360000ms Bash timeout; use `TEST_FILTER` with 120000ms for unit tests
- LP structure tests for SDDP-integrated functions use `SDDP.LinearPolicyGraph` as harness with a `Ref{JuMP.Model}` captured in the closure
- GLPK is NOT thread-safe; use HiGHS for any test that exercises `SDDP.Threaded()`

## Variable Symbol Registration

- Every new JuMP variable or expression: `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl` + export in `src/Lab/Lab.jl`
- Epic 07 added no new variable symbols (VAR reuses `STCHP`, `ω_INFLOW`, `INFLOW`, `INFLOW_SLACK`, `NOISE_ADJUSTMENT_SLACK`)
