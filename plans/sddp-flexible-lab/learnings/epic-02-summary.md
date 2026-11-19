# Accumulated Learnings Summary -- Epic 02

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
- `SDDPPolicyTaskDefinition` holds one field per dimension; `SDDPSimulationTaskDefinition` holds `parallel_scheme` and `sampling_scheme`
- Each dimension has a `generate_*` multi-method function mapping SDDPlab types to SDDP.jl types (`src/Engines/sddp/input.jl`)
- Parameterless types (Expectation, Serial, DefaultSampling, SingleCut, etc.) use a trivial constructor that ignores the dict
- Parameterized types (AVaR, Entropic, InSampleMC, RegularizedForwardPassStrategy) define a `const SCHEMA` and use `validate_schema!`

## Composite/Nested Types Pattern

- `ConvexCombination` (risk measures with weights), `StoppingChain` (AND-chained rules), `BanditDualityHandler` (bandit over handlers) all hold vectors of their parent abstract type
- Construction: validate container key -> iterate entries -> resolve each via factory -> type-check -> composite validation (weight sum, min count)
- Canonical implementation: `__build_convex_combination_internals!` in `src/Engines/sddp/input.jl`

## Backward Compatibility Pattern

- Optional algorithm fields use `haskey` check in their `__build_*!` functions; if absent, inject a Default\* sentinel instance
- "Before build" validators only check type of optional keys if the key is present
- `Convergence.stopping_criteria` always normalizes to `Vector{StoppingCriteria}` (single dict is wrapped)
- `Default*` sentinel types (`DefaultSampling`, `DefaultDuality`, `DefaultForwardPassStrategy`) map to SDDP.jl defaults or are omitted from kwargs

## Train/Simulate Pipeline Wiring

- `train.jl` builds a `Dict{Symbol,Any}` of kwargs, conditionally adds non-default options, splats into `SDDP.train(model; kwargs...)`
- `simulate.jl` uses `generate_sampling_scheme(scheme, graph_size)` dual-arity dispatch for simulation sampling
- `save_policy.jl` handles both SingleCut and MultiCut via `__get_node_cutdata` which returns whichever cut array is non-empty

## SDDP.jl API Quirks Discovered

- `SDDP.Wasserstein` requires a norm function as first positional arg: `SDDP.Wasserstein(x -> sum(abs, x), solver; alpha=a)`
- `SDDP.ModifiedChiSquared` uses `minimum_std` (not `minimum_concentration` as some docs suggest)
- `SDDP.Statistical` needs `disable_warning=true` to suppress convergence warnings in short test runs
- `SDDP.SimulationStoppingRule` is parametric; test with `<:` not `===`
- `SDDP.SINGLE_CUT` and `SDDP.MULTI_CUT` are enum values of type `SDDP.CutType`, not types
- `SDDP.EAVaR(; beta, lambda)` is used internally by CVaR mapping with `lambda = 1 - user_lambda`
- `SDDP.BanditDuality` and `SDDP.ConvexCombination` take splatted args, not vectors

## Testing Conventions

- Three helpers: `__renew(DICT)`, `__modif_key(d, k, v)`, `__remove_key(d, k)` -- start from valid, mutate one thing
- Pipeline integration tests construct typed objects directly (not from JSONC), overlay onto a read study via `Study(original.inputs, custom_engine)`
- Each new algorithm option gets at least one full pipeline test in `test/test-main.jl`
- Mapping tests in `test/Engines/sddp/test-sddp-mappings.jl` verify `generate_*` returns correct SDDP.jl types

## Key Observations for Future Epics

- Adding new SDDP options: 6-step recipe (struct, field, constructor, generate*\*, \_\_build*\*!, wire kwargs) -- proven 20+ times in Epic 02
- Always verify SDDP.jl API parameter names in REPL before coding (`methods(SDDP.TypeName)`)
- Cross-entity validators go in parent module's validator file (established in Epic 01, unchanged in Epic 02)
- Graph architecture decouples from sequential stages; load uses node_id for future branching/cyclic support
- `RiskAdjustedForwardPassStrategy` hardcodes inner params (AVaR 0.5, resampling 0.5) -- consider making configurable later
- OutOfSampleMC and Historical sampling deferred to future ticket due to complex JSONC structure requirements
