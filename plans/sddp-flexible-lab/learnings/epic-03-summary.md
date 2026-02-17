# Accumulated Learnings Summary -- Epic 03

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures (missing keys, type conversion); `AssertionError` for semantic violations
- Errors accumulate in `CompositeException` -- never thrown, always pushed
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`
- Predicate factories: `positive()`, `non_negative()`, `in_range(lo,hi)`, `in_range_exclusive(lo,hi)`, `greater_than(n)`, `less_than(n)`, `non_empty()`, `matches(regex)`, `unique_in(key)`
- Per-field short-circuits (missing -> skip type, bad type -> skip constraints), but cross-field does NOT short-circuit
- Schema handles ~80% of boilerplate for simple entities, ~30% for complex entities with cross-field/cross-entity logic

## kind_factory! Extension Mechanism

- `__kind_factory!(module, dict, key, e)` resolves `{"kind": "TypeName", "params": {...}}` to Julia objects via `getfield(module, Symbol(kind))`
- No registry needed; define the struct and its `TypeName(d::Dict{String,Any}, e::CompositeException)` constructor
- `__single_object_factory` is the underlying helper for one-at-a-time resolution (used in composite types)

## Algorithm Option Type System (Epic 02)

- Seven abstract type dimensions: `StoppingCriteria`, `RiskMeasure`, `ParallelScheme`, `SamplingScheme`, `DualityHandler`, `ForwardPassStrategy`, `CutType`
- Eighth dimension added in Epic 03: `ScalingMode` with `NoScaling` and `AutoScaling`, following identical kind_factory! pattern
- `SDDPPolicyTaskDefinition` holds one field per dimension; `SDDPSimulationTaskDefinition` holds `parallel_scheme` and `sampling_scheme`
- Each dimension has a `generate_*` multi-method function mapping SDDPlab types to SDDP.jl types (`src/Engines/sddp/input.jl`)
- Parameterless types use a trivial constructor that ignores the dict; parameterized types define a `const SCHEMA` and use `validate_schema!`

## Scaling System (Epic 03)

- Scaling is input-data rescaling (preprocess SystemData before model build), NOT LP-level transformation
- `compute_scaling_factors(system)` derives per-category factors from actual data ranges (`src/Engines/sddp/scaling.jl`)
- Hydro balance constraint requires unified factor for storage, flow, spillage, inflow: `s_hydro = max(max_storage, max_flow)`
- Productivity scaling: `prod_scaled = prod * s_flow / s_gen`; penalty scaling: `pen_scaled = pen * s_flow / (s_cost * s_gen)`
- SAA inflow values and load values must also be divided by scaling factors during subproblem building
- `ScalingConfig` flows through: `SDDPModel` -> `SDDPSimulationTaskArtifact` -> `save_simulation.jl` for unscaling
- `_get_variable_unscale_factor` in `save_simulation.jl` maps each variable symbol to its unscale factor -- must be updated for new variables
- Synthetic symbols `FLOW_SCALE` and `COST_SCALE` carry cross-cutting factors not tied to a single JuMP variable

## Engine-Level Configuration (Epic 03)

- `SDDPEngine` gained `diagnostics::DiagnosticsConfig` and `solver::SolverConfig` as optional JSONC fields
- Both use `haskey`-based backward compat with defaults: `DiagnosticsConfig(false, 1e6, 1e10)` and `SolverConfig("GLPK", Dict())`
- `__build_diagnostics!` and `__build_solver!` follow same pattern as policy-level `__build_*!` functions
- `__build_sddp_engine_internals_from_dicts!` chains: policy, simulation, diagnostics, solver
- Cross-field validation (halt >= warn) runs after schema validation, same pattern as `__validate_convergence_min_max!`

## Solver and Diagnostics Infrastructure (Epic 03)

- `create_optimizer(config)` returns a zero-arg factory closure; attributes set via `MOI.RawOptimizerAttribute` inside closure
- HiGHS lazy-loaded via `Base.require(Main, :HiGHS)` -- not tested; requires HiGHS.jl installed
- `build(study)` is now the primary API; `build(study, optimizer)` deprecated with `Base.depwarn`
- `run_diagnostics` parses SDDP.numerical_stability_report text output via regex for coefficient ranges
- `diagnose(study, model)` in study.jl is a public API but not auto-invoked in the pipeline

## Units Registry (Epic 03)

- `src/Utils/units.jl`: `PhysicalUnit` struct with 8 constants (MW, MWh, HM3, etc.), `UnitConversion` and `UNIT_CONVERSIONS` dict
- `src/Utils/variable-units.jl`: `VARIABLE_UNITS_REGISTRY` maps 10 variable symbols to expected units and magnitude ranges
- `get_coefficient_magnitude_report(model)` traverses JuMP model variables and reports actual vs. expected magnitudes
- Purely metadata -- no impact on entity types, JSONC schemas, or runtime behavior

## Backward Compatibility Pattern

- Optional algorithm fields use `haskey` check; if absent, inject a Default\*/NoScaling/default config instance
- "Before build" validators only check type of optional keys if the key is present
- `Convergence.stopping_criteria` always normalizes to `Vector{StoppingCriteria}` (single dict is wrapped)
- `build(study, optimizer)` kept but deprecated; all tests updated to use `build(study)` or internal `Lab.build` signatures

## Testing Conventions

- Three helpers: `__renew(DICT)`, `__modif_key(d, k, v)`, `__remove_key(d, k)` -- start from valid, mutate one thing
- Pipeline integration tests construct typed objects directly, overlay onto a read study via `Study(original.inputs, custom_engine)`
- Scaling tests build minimal `SystemData` directly with entity constructors to verify factor computation
- Diagnostics tests build small SDDP.LinearPolicyGraph models to verify threshold behavior
- Solver tests verify `create_optimizer` returns a working factory and attributes are applied

## SDDP.jl API Quirks Discovered

- `SDDP.numerical_stability_report(io, model; print=true, warn=true)` -- IO is positional arg, not keyword
- `SDDP.Wasserstein` requires a norm function as first positional arg
- `SDDP.ModifiedChiSquared` uses `minimum_std` (not `minimum_concentration`)
- `SDDP.Statistical` needs `disable_warning=true` to suppress convergence warnings in short test runs
- `SDDP.SINGLE_CUT` and `SDDP.MULTI_CUT` are enum values, not types

## Key Observations for Future Epics

- Adding new system elements (Epic 05): must update `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, and `VARIABLE_UNITS_REGISTRY`
- Adding engine-level config: add `__build_*!` to `src/Engines/sddp/input.jl`, field to `SDDPEngine`, line to `__build_sddp_engine_internals_from_dicts!`
- Adding new SDDP options: 6-step recipe (struct, field, constructor, generate*, \_\_build*!, wire kwargs) proven 20+ times
- Always verify SDDP.jl API parameter names in REPL before coding (`methods(SDDP.TypeName)`)
- HiGHS solver path untested; add integration test when HiGHS becomes a test dependency
- `diagnose` step is manual; consider auto-running between build and train in a future ticket
