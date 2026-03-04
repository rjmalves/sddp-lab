# Accumulated Learnings Summary — Epic 08

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures; `AssertionError` for semantic violations; errors accumulate, never thrown
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)
- `SystemData` always has all fields as required; empty sets represent absent entity types; backward compat via `haskey` guards
- Abstract sentinel type is the default for optional engine fields (e.g., `NoMarkovChain`/`MarkovChainConfig`); `Union{T, Nothing}` reserved for fields where absence should error
- New fields on `SystemData` or `ScenariosData` are never `Union{T,Nothing}`; always required with empty/default values

## Orchestration Layer Pattern (Epic 08)

- New orchestration code that calls `build`, `train`, `simulate`, `save_*` must use plain `include()` into `SDDPlab` scope — NOT a Julia submodule — so pipeline functions are in scope without qualification; see `src/Experiments/Experiments.jl`
- Every pipeline call inside an orchestration function must use `Base.invokelatest(fn, args...)` to avoid Julia world-age errors when test harnesses load solver packages after precompilation; see `src/Experiments/runner.jl` lines 137-180
- Deep merge engine overrides into the raw `Dict{String,Any}` before calling `Study(dict, e)` — the existing construction pipeline validates the merged result automatically; see `src/Experiments/merge.jl`
- Always `deepcopy(base_dict)` before each config run — `Study()` mutates its input dict in-place; without this, subsequent runs see corrupted dicts
- Manage `pwd()` with explicit `cd(target)` / `cd(original_pwd)` pairs; restore `original_pwd` in the catch branch; see `src/Experiments/runner.jl` lines 79-192

## Reproducibility Infrastructure (Epic 08)

- `JSON.jl` does NOT sort keys during serialization; deterministic hashing requires a custom `_write_json_sorted` recursive serializer; see `src/Experiments/reproducibility.jl` lines 232-265
- `hash_config` uses `SHA.sha256` (Julia stdlib) on the sorted-key canonical JSON; returns 64-char lowercase hex
- `capture_environment()` reads package versions via `Pkg.dependencies()` wrapped in try-catch; failure records "unknown" and logs `@warn`
- `write_run_metadata` is non-fatal: all file I/O wrapped in try-catch with `@warn`; never aborts an experiment run
- `verify_reproducibility` compares `config_hash` fields from two `metadata.json` files; warns (does not fail) when thread counts differ

## Result Aggregation (Epic 08)

- Use `STAGE_COST` rows (not `TOTAL_COST`) when computing per-scenario total policy cost from simulation output; `TOTAL_COST` includes future cost estimates and double-counts; see `src/Experiments/comparison.jl` line 234
- 10-metric statistical summary (mean, std, CI bounds, p05/p50/p95, min, max, n) is duplicated in `comparison.jl` rather than importing from engine internals — preserves module boundary isolation
- `aggregate_experiment_results` scans all subdirectories; missing `operation_system.csv` causes `@warn` + skip, not error

## Block Variable Dimensionality (Epic 06)

- All power and flow decision variables are permanently 2D `[entity, block]` even for K=1; `src/Engines/sddp/build.jl` lines 46-216
- State variables (`STORED_VOLUME`) and inflow variables are always 1D; `BLOCK_STORAGE` is a regular JuMP variable, NOT `SDDP.State`
- `BlockConfig` lives on `ScenariosData` as a required field; `default_block_config()` returns empty blocks; `has_blocks(bc)` distinguishes configured vs. default

## Modeling Options Pattern (Epics 06-07)

- `SDDPEngine` has 6 fields as of Epic 07; future options go under `"modeling"` sub-dict with `__build_OPTION!` in `src/Engines/input.jl`
- Multiple dispatch on method type for objective contribution avoids if/else chains (`src/Engines/sddp/build.jl` lines 340-385)

## Stochastic Process Architecture (Epics 01-07)

- All processes implement `AbstractStochasticProcess`; auto-resolved via `__kind_factory!` — no registration needed
- Three types: `Naive`, `AutoRegressive` (PAR(p)), `VectorAutoRegressive` (VAR(p) with N×N coefficient matrices in normalized space)
- VAR STCHP flat indexing: `index_t[n] = (n-1) * max_lag + 1`; recurrence in normalized `(X-mu)/sigma` space

## Markov Chain Architecture (Epic 07)

- `AbstractMarkovChain` / `NoMarkovChain` / `MarkovChainConfig` in `src/Scenarios/markov.jl`
- `InflowScenarios.stochastic_process` is `Dict{Int, AbstractStochasticProcess}`; legacy JSONs wrapped in `Dict(1 => process)` at parse time
- When Markov active: `__build_graph` returns `SDDP.MarkovianGraph(mc.transition_matrices)`, bypasses SDDPlab `Graph` entirely
- Per-state SAA uses prime offset: `seed + (state - 1) * 7919` for independence across Markov states

## Out-of-Sample Validation (Epic 07)

- `OutOfSampleValidation` (4 fields) is the 6th field on `SDDPEngine` as `Union{T, Nothing}` — sole `Union` exception
- `_t_quantile_95(df)` is an inline lookup table (no `Distributions.jl` dependency)
- Output uses `validation_` prefix on all file names; logic in `save_validation.jl` mirrors `save_simulation.jl`

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`; handles ~80% of flat scalar field boilerplate
- Nested dicts and variable-length vectors require custom validators

## Scaling System

- Six touch points for every new variable symbol: `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, `map_variable_entities`
- `no_scaling_config()` must include every new symbol; missing symbols cause `KeyError` at simulation output time
- Validation output maps in `validate.jl` are a separate copy from simulation output maps — update both

## Algorithm Option Type System

- Ten abstract type dimensions; parameterless subtypes use `Type(::Dict, ::CompositeException) = Type()`
- New options follow the 6-step recipe: struct, field on engine, constructor, `generate*`, `__build*!`, wire kwargs

## Testing Conventions

- Always create new test files; never add to large existing files (SIGABRTs observed with `test-engines.jl`)
- Never run `test-main` without 360000ms Bash timeout; use `TEST_FILTER` with 120000ms for unit, 180000ms for integration
- GLPK is NOT thread-safe; use HiGHS for any test that exercises `SDDP.Threaded()`
- `mktempdir() do tmpdir ... end` for all integration tests that write output files
- Use `example/1dtoy` as the base study; set `max_iterations: 3`, `num_simulated_series: 2-5` to keep tests fast

## Variable Symbol Registration

- Every new JuMP variable or expression: `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl` + export in `src/Lab/Lab.jl`
- Epic 08 added no new JuMP variable symbols (experiment layer does not modify the model)
