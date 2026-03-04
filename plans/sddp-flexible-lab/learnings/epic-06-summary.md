# Accumulated Learnings Summary -- Epic 06

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures; `AssertionError` for semantic violations; errors accumulate, never thrown
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)
- `SystemData` always has all fields as required; empty sets represent absent entity types; backward compat via `haskey` guards in the parser

## Optional Entity and Config Pattern

- New fields on `SystemData` or `ScenariosData` are never `Union{T,Nothing}`; always required with empty/default values
- Backward compat: `haskey(d, "key")` in internals builder creates defaults when key is absent; resolved object is injected into dict before schema validation
- Every `add_system_elements!(m, ses::NewType)` begins with `if length(ses) == 0; return nothing; end`

## Block Variable Dimensionality (Epic 06)

- All power and flow decision variables are permanently 2D `[entity, block]` even for K=1; no branching between 1D and 2D (`src/Engines/sddp/build.jl` lines 46-216)
- State variables (`STORED_VOLUME`) and inflow variables (`INFLOW`, `omega_INFLOW`, `STCHP`) are always 1D -- SDDP cut generation requires stage-level state
- `BLOCK_STORAGE` (chronological mode intermediate volumes) is a regular JuMP variable, NOT `SDDP.State`; making it a state variable breaks dual values and cut generation
- `BlockConfig` lives on `ScenariosData` as a required field; `default_block_config()` returns empty blocks; `has_blocks(bc)` distinguishes configured vs. default (`src/Scenarios/blocks.jl`)
- Block durations parsed at scenarios-load time; tau per node computed at build time; block-duration-sum validation not enforced (cross-time-domain constraint)
- Block names stored as strings in `DeterministicLoadValue`; `get_load` converts block index to name via `bc.blocks[block_idx].name` (`src/Scenarios/Scenarios.jl` lines 66-76)

## Modeling Options Pattern (Epic 06)

- `SDDPEngine` now has 5 fields; 5th is `inflow_non_negativity::InflowNonNegativity`; parsed under optional `"modeling"` JSON key; defaults to `InflowNone()` when absent
- Future modeling options: add to `"modeling"` sub-dict, add `__build_OPTION!` in `src/Engines/input.jl`, add type hierarchy to `src/Engines/Engines.jl`, pass through `__generate_subproblem_builder`
- Multiple dispatch on method type for objective contribution: `_inflow_penalty_expr(m, method, tau_k, scaling)` returns `0.0` for non-penalty methods; avoids if/else chains (`src/Engines/sddp/build.jl` lines 404-454)
- Side-channel data between builder functions via `m.ext` dict (e.g., `m.ext[:noise_adjustment_sigma]`); typed context struct preferred for future growth

## JuMP.fix and Lower Bound Conflict (Epic 06)

- Variables set via `SDDP.parameterize` with `JuMP.fix` cannot simultaneously carry hard lower bounds; fixing outside the bound causes LP infeasibility
- `InflowTruncation` is SAA-side only (`max.(0.0, omega)`) and does NOT guarantee non-negative inflows; confirmed limitation
- For guaranteed non-negativity: use `InflowPenalty` (adds `INFLOW_SLACK`, decouples `INFLOW >= 0` from `STCHP.out`) or `InflowTruncationWithPenalty`

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`; predicates: `positive()`, `non_negative()`, `in_range`, `matches`, etc.
- Handles ~80% of boilerplate for flat scalar fields; nested dicts and variable-length vectors require custom validator functions

## Bus Index Map and Load Balance

- `_build_bus_index_map(entities, ids, field::Symbol)` maps any `ids` vector to entity positions via any field; 10 maps precomputed in `__generate_subproblem_builder`
- `__add_load_balance!` now has 14 parameters; refactor to context struct before reaching 15+

## Scaling System

- `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, `map_variable_entities` are six touch points for every new variable symbol
- `no_scaling_config()` must include every new symbol; missing symbols cause `KeyError` at simulation output time
- New in Epic 06: `BLOCK_STORAGE`, `INFLOW_SLACK` (unscale: `s_flow`), `NOISE_ADJUSTMENT_SLACK` (unscale: 1.0)

## Simulation Output (Epic 06)

- `__variable_exists_in_sim(simulations, variable)` must be called before processing optional variables (absent when non-default method inactive) (`src/Engines/sddp/save_simulation.jl` lines 276-278)
- `__is_2d_variable` detects `AbstractMatrix`; block-indexed outputs append `_B1`, `_B2`, ... to variable names
- `BLOCK_STORAGE` (chronological intermediate volumes) intentionally excluded from output maps -- debugging artifact, not operational output

## Algorithm Option Type System

- Nine abstract type dimensions (added `InflowNonNegativity` in Epic 06): full list in `src/Engines/Engines.jl`
- Parameterless subtypes: `Type(::Dict, ::CompositeException) = Type()`; parameter-bearing subtypes: schema-validated constructors
- Shared schema constants can cover types with identical fields; split when fields diverge

## Testing Conventions

- Always create new test files; never add to large existing files (SIGABRTs observed)
- Never run `test-main` without 360000ms Bash timeout; use `TEST_FILTER` with 120000ms for unit tests
- LP structure tests for SDDP-integrated functions use `SDDP.LinearPolicyGraph` as harness with a `Ref{JuMP.Model}` captured in the closure
- GLPK is NOT thread-safe; use HiGHS for any test that exercises `SDDP.Threaded()`

## Variable Symbol Registration

- Every new JuMP variable or expression: `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl` + export in `src/Lab/Lab.jl`
- New in Epic 06: `BLOCK_STORAGE`, `INFLOW_SLACK`, `NOISE_ADJUSTMENT_SLACK`
