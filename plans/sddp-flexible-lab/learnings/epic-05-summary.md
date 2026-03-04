# Accumulated Learnings Summary -- Epic 05

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures (missing keys, type conversion); `AssertionError` for semantic violations
- Errors accumulate in `CompositeException` -- never thrown, always pushed
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)
- `SystemData` always has all fields as required (currently 7); empty sets represent absent entity types; backward compat is in the parser via `haskey` guards, not in the type

## Optional Entity Pattern (Epic 05)

- New entity fields in `SystemData` are never `Union{T,Nothing}`; always required with empty-set defaults
- Backward compat: `haskey(d, "key")` in `__build_system_internals_from_dicts!` creates empty sets when key is absent; `CONFIGURATION_KEYS` is NOT extended (it lists only required keys)
- Every `add_system_elements!(m, ses::NewType)` begins with `if length(ses) == 0; return nothing; end` to avoid KeyError in `__add_load_balance!`
- Cross-entity validators (e.g., pumpingstation referencing hydros) require the referenced entity set to be built first; enforce via `(valid_buses && valid_hydros) && __build_pumpingstations!(...)`
- Reference: `src/System/systemdata-validators.jl` lines 48-65

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`
- Predicate factories: `positive()`, `non_negative()`, `in_range(lo,hi)`, `in_range_exclusive(lo,hi)`, `greater_than(n)`, `less_than(n)`, `non_empty()`, `matches(regex)`, `unique_in(key)`
- Schema handles ~80% of boilerplate for simple entities; nested dicts require manual validators (`__validate_ENTITY_FIELDNAME!` returning `Bool`)
- Nested dict fields: validated manually in `__validate_*_content!`; sub-keys are extracted and stored as flat struct fields at construction time

## Bus Index Map -- Now General-Purpose

- `_build_bus_index_map(entities, ids, field::Symbol)` in `src/Engines/sddp/build.jl` maps any `ids` vector to entity positions via any field
- Reused without modification for hydro coupling: `pump_source_map = _build_bus_index_map(pumping_entities, hydro_ids, :source_hydro_id)`
- Six maps are now precomputed in `__generate_subproblem_builder` (lines 420-428): hydro, thermal, noncontrollable, contract, pumping (bus), pump source (hydro), pump dest (hydro), line source, line target
- Import vs. export sign difference is resolved inline in `__add_load_balance!` (not via separate filtered maps) to avoid sub-vector index mismatch

## Scaling System

- `compute_scaling_factors` must include all new variable magnitudes in `all_gen` and `all_costs` collections
- Cost scaling uses `abs()` for prices that can be negative (export contract revenue); without `abs()` negative prices reduce `max_cost`
- Multi-unit scaling: `consumption_mw_per_m3s` scales as `consumption * s_flow / s_hgen` -- derived by requiring `consumption_scaled * flow_scaled == power_scaled`
- `apply_scaling` constructs a new `SystemData` with all 7 fields; missing any field causes an immediate compile error (reliable checklist item)
- `_get_variable_unscale_factor` in `save_simulation.jl` must be updated for every new symbol: `NC_GENERATION/NC_CURTAILMENT => s_gen`, `CONTRACT_DISPATCH => s_gen`, `PUMPED_FLOW => s_flow`, `PUMP_POWER => s_gen`

## kind_factory! Extension Mechanism

- `__kind_factory!(module, dict, key, e)` resolves `{"kind": "TypeName", "params": {...}}` to Julia objects via `getfield(module, Symbol(kind))`
- No registry needed; define the struct and its `TypeName(d::Dict{String,Any}, e::CompositeException)` constructor

## Algorithm Option Type System

- Eight abstract type dimensions: `StoppingCriteria`, `RiskMeasure`, `ParallelScheme`, `SamplingScheme`, `DualityHandler`, `ForwardPassStrategy`, `CutType`, `ScalingMode`
- Runtime warnings belong in `generate_*` methods, not in constructors
- `Distributed` stdlib imported at module load in `src/Engines/Engines.jl` line 10; negligible cost

## Parallel Scheme Patterns (Epic 04)

- GLPK is NOT thread-safe; `SDDP.Threaded()` with GLPK causes SIGABRT; use HiGHS for threaded training tests
- Integration tests for `Asynchronous` use `@test_skip` with `Distributed.nprocs() == 1` guard

## Thread-Safe SAA Generation (Epic 04)

- Use `MersenneTwister(seed)` (not global RNG); `build.jl` calls `generate_saa(scenarios, num_stages, scenarios.seed)` at line 339
- `set_seed!` in `src/Scenarios/Scenarios.jl` emits `Base.depwarn` (kept for compat)

## Build Performance Optimizations (Epic 04)

- Entity lists and bus maps are precomputed once in `__generate_subproblem_builder` before the closure, not per-node
- In-place SAA sampling with `rand!(rng, D, buffer)` replaces `rand(rng, D, 1)` per sample
- JuMP `@variable`/`@constraint` macros dominate build time; no further improvement without MOI-level changes

## Variable Symbol Registration

- Every new JuMP variable or expression: `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl` + export in `src/Lab/Lab.jl`
- New in Epic 05: `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW`, `PUMP_POWER`

## Testing Conventions

- Three helpers: `__renew(DICT)`, `__modif_key(d, k, v)`, `__remove_key(d, k)` -- start from valid, mutate one thing
- Always create new test files; never add to large existing files (SIGABRTs observed)
- Never run `test-main` without a 360000ms Bash timeout; it can hang indefinitely (confirmed during Epic 05)
- Use `TEST_FILTER="test-ENTITYNAME"` (120000ms timeout) for unit test verification
- Pumpingstation test must build its own `HYDROS` object as a test fixture (cross-entity dependency): see `test/System/test-pumpingstation.jl` lines 40-43

## SDDP.jl API Quirks

- `sum(expr for j in Int[])` in JuMP constraints evaluates to 0 correctly (used in `add_hydro_balance!` for empty pump maps)
- JuMP expressions (`@expression`) are the correct form for derived quantities (curtailment, pump power, net exchange) -- no extra LP rows

## Key Observations for Epic 06+

- Adding stage time duration: affects load scaling per stage in `__add_load_balance!`; deeper than a new entity type; do not underestimate
- Adding inner load blocks: changes all variable shapes from `[n]` to `[n, block]`; load balance and objective must be restructured; affects all existing entity contributions
- Inflow non-negativity: `INFLOW` is set by `JuMP.fix` in parameterize; a lower bound conflicts with `fix`; use a slack variable approach
- `__add_load_balance!` now has 14 parameters; consider a context struct if it grows beyond 18
- Any nested dict field in an Epic 06+ entity requires a manual validator (FieldRule schema does not handle nesting)
- Cross-entity constructors beyond `buses`: pass the additional entity set as an extra argument; enforce build order in `__build_system_internals_from_dicts!`
