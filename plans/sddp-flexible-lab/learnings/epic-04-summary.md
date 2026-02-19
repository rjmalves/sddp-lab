# Accumulated Learnings Summary -- Epic 04

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
- Parameterless `ParallelScheme` subtypes (`Serial`, `Asynchronous`, `Threaded`) all resolve automatically through `kind_factory!` with no validator changes needed

## Algorithm Option Type System

- Eight abstract type dimensions: `StoppingCriteria`, `RiskMeasure`, `ParallelScheme`, `SamplingScheme`, `DualityHandler`, `ForwardPassStrategy`, `CutType`, `ScalingMode`
- `ParallelScheme` now has three subtypes: `Serial`, `Asynchronous`, `Threaded` (in `src/Engines/Engines.jl` lines 70-74)
- Each dimension has a `generate_*` multi-method mapping SDDPlab types to SDDP.jl types (`src/Engines/sddp/input.jl`)
- Runtime warnings belong in `generate_*` methods, NOT in constructors -- constructors run at config-parse time, generate methods run at train/simulate time when the runtime state (thread count, worker count) matters
- `Distributed` stdlib is now imported at module load in `src/Engines/Engines.jl` line 10; has negligible cost and never spawns workers on its own

## Parallel Scheme Patterns (Epic 04)

- `Threaded`: added `struct Threaded <: ParallelScheme end` and `generate_parallel_scheme(::Threaded)` returning `SDDP.Threaded()` with a `@warn` when `Threads.nthreads() == 1` (`src/Engines/sddp/input.jl` lines 398-403)
- `Asynchronous`: hardened with `@warn` when `Distributed.nprocs() == 1` and a docstring explaining user worker setup requirements (`src/Engines/sddp/input.jl` lines 371-396)
- GLPK is NOT thread-safe -- `SDDP.Threaded()` with GLPK causes SIGABRT; use HiGHS for threaded training tests (documented in `plans/sddp-flexible-lab/00-master-plan.md`)
- Integration tests for `Asynchronous` that require workers use `@test_skip` with `Distributed.nprocs() == 1` guard (pattern in `test/test-main.jl` lines 467-507)
- Thread safety tests: verify only type wiring, not full threaded training with GLPK (pattern: `1dtoy-threaded-type-wiring` and `1dtoy-asynchronous-type-wiring` in `test/test-main.jl`)
- `Threaded` is exported from `Engines` module; `Asynchronous` was already exported -- check export list when adding new parallel scheme subtypes

## Thread-Safe SAA Generation (Epic 04)

- Global RNG mutation (`Random.seed!` + `Random.default_rng()`) is thread-unsafe; replaced with explicit `MersenneTwister(seed)` in `src/StochasticProcess/StochasticProcess.jl` lines 58-67
- New overload: `generate_saa(s, initial_season, N, B, seed::Integer)` creates a `MersenneTwister(seed)` and calls `__generate_saa(rng, ...)` -- the seed-passing path is now the primary production path
- `set_seed!` in `src/Scenarios/Scenarios.jl` lines 56-63 is kept for backward compat but emits `Base.depwarn`
- `__generate_saa` in `naive.jl` and `autoregressive.jl` already accepted `rng::AbstractRNG` as first arg; the fix was only in the public API layer
- `build.jl` now calls `generate_saa(scenarios, num_stages, scenarios.seed)` at line 339, eliminating global RNG mutation during model building
- Use `MersenneTwister` (not `TaskLocalRNG`) for explicit RNG -- `MersenneTwister` is deterministic for a given seed independent of task/thread identity
- Test: verify global RNG state is unchanged after `generate_saa` with seed -- uses `copy(Random.default_rng())` and compares `rand()` before/after (see `test/Scenarios/test-scenariosdata.jl` lines 222-234)

## Build Performance Optimizations (Epic 04)

- Entity lookups (`get_hydros_entities`, `get_thermals_entities`, `get_lines_entities`, `get_ids(get_buses(...))`) are now precomputed once in `__generate_subproblem_builder` before the closure, not per-node call (`src/Engines/sddp/build.jl` lines 350-358)
- `_build_bus_index_map(entities, bus_ids, bus_field::Symbol)` helper (lines 316-330 of `build.jl`) precomputes `Dict{Int,Vector{Int}}` mapping bus position to entity indices; replaces O(num_entities) filter generators with O(1) `get(map, n, Int[])` lookups in `__add_load_balance!`
- Four maps are precomputed: `hydro_bus_map` (`:bus_id`), `thermal_bus_map` (`:bus_id`), `line_target_map` (`:target_bus_id`), `line_source_map` (`:source_bus_id`)
- In-place SAA sampling: `rand!(rng, D, buffer)` with a preallocated `buffer = zeros(size_s[1], 1)` replaces `rand(rng, D, 1)` per sample; `.= @view buffer[:, 1]` replaces `.+=` (`src/StochasticProcess/naive.jl` lines 53-74)
- Actual speedup on 4ree: 10% time reduction, <1% allocation reduction -- JuMP's `@variable`/`@constraint` macros dominate total allocations and cannot be reduced without changing JuMP internals
- Benchmark script: `benchmark/bench_build.jl` with `@benchmark(quiet_build(study), samples=5, evals=1)` and `NullLogger()` to exclude logging overhead; results documented in `benchmark/RESULTS.md`
- Path to 2x speedup would require lazy constraint sharing, direct MOI API usage, or model templating via `MOI.copy_to` -- outside current scope

## Scaling System (from Epic 03, unchanged)

- Scaling is input-data rescaling (preprocess SystemData before model build), NOT LP-level transformation
- `compute_scaling_factors(system)` derives per-category factors from actual data ranges (`src/Engines/sddp/scaling.jl`)
- `ScalingConfig` flows through: `SDDPModel` -> `SDDPSimulationTaskArtifact` -> `save_simulation.jl` for unscaling
- `_get_variable_unscale_factor` in `save_simulation.jl` maps each variable symbol to its unscale factor -- must be updated for new variables
- Synthetic symbols `FLOW_SCALE` and `COST_SCALE` carry cross-cutting factors not tied to a single JuMP variable

## Engine-Level Configuration (from Epic 03, unchanged)

- `SDDPEngine`: 4 fields (`policy`, `simulation`, `diagnostics`, `solver`)
- `DiagnosticsConfig` and `SolverConfig` use `haskey`-based backward compat with defaults
- `build(study)` is the primary API; `build(study, optimizer)` is deprecated

## Testing Conventions

- Three helpers: `__renew(DICT)`, `__modif_key(d, k, v)`, `__remove_key(d, k)` -- start from valid, mutate one thing
- Pipeline integration tests construct typed objects directly, overlay onto a read study via `Study(original.inputs, custom_engine)`
- New test files for Epic 04: `test/Engines/test-threaded.jl` (Threaded wiring), `test/Engines/sddp/test-build-optimizations.jl` (bus index map + load balance equivalence), scenarios data thread-safety tests added to `test/Scenarios/test-scenariosdata.jl` lines 176-239
- Deleted `test/Engines/sddp/test-parallelscheme.jl` (replaced by `test-threaded.jl` and `test-sddp-mappings.jl` entries)
- DO NOT add new tests to large existing test files; always create a separate file (SIGABRTs observed in prior epics when adding to `test-engines.jl`)

## SDDP.jl API Quirks

- `SDDP.Threaded()` auto-detects `Threads.nthreads()` -- do NOT add a thread count parameter to the `Threaded` struct
- `SDDP.Asynchronous()` requires workers set up by user (`julia -p N` or `addprocs(N)`) + `@everywhere` package loading; SDDPlab must not call `addprocs()` itself
- `Copulas.SklarDist` supports in-place `rand!(rng, D, buffer)` -- verified during Epic 04 optimization work

## Test Execution Protocol (CRITICAL)

- **Always use TEST_FILTER**: `export TEST_FILTER="test-xyz" && julia --project -e 'using Pkg; Pkg.test()'` -- never run the full suite without filtering
- **Always set Bash timeout**: 120000ms for unit tests, 180000ms for integration tests -- the full suite takes ~4 min
- **GLPK is NOT thread-safe**: use HiGHS for any test that actually exercises `SDDP.Threaded()` training; type-wiring tests with GLPK are safe because they never call `SDDP.train`
- **Use separate test files**: adding to large existing files caused unexplained SIGABRTs; create new files instead
- See `plans/sddp-flexible-lab/00-master-plan.md` for full protocol

## Key Observations for Future Epics

- Adding new `ParallelScheme` subtypes: 3-step recipe (struct in `Engines.jl`, constructor in `input.jl`, `generate_parallel_scheme` method in `input.jl`; no validator changes needed); add runtime guard in generate method, not constructor
- Adding new system elements (Epic 05): must update `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `VARIABLE_UNITS_REGISTRY`, AND the new `_build_bus_index_map` call sites in `__generate_subproblem_builder` if the element has bus assignments
- Adding new engine-level config: add `__build_*!` to `src/Engines/sddp/input.jl`, field to `SDDPEngine`, line to `__build_sddp_engine_internals_from_dicts!`
- SAA generation is inherently single-threaded (called once before SDDP.jl starts forward passes); thread safety is about NOT mutating global state, not about parallelizing SAA itself
- When adding new stochastic process types (Epic 06): implement `__generate_saa(rng::AbstractRNG, s::NewType, ...)` -- the seed-passing public API will work automatically
- HiGHS solver path untested in CI; add integration test when HiGHS becomes a test dependency
- Benchmark infrastructure is now in `benchmark/bench_build.jl` -- extend it when new system elements are added to measure regression in build performance
