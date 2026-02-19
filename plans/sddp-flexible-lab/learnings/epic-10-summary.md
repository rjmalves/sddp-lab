# Accumulated Learnings Summary — Epics 01-10

## Core Construction Pattern

- All entities construct from `Dict{String,Any}` + `CompositeException`; return `nothing` on failure; never throw
- Four-phase pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gated by `&&`
- `ErrorException` for structural failures (wrong type, missing key); `AssertionError` for semantic violations (value out of range)
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas)
- `FieldRule` / `validate_schema!` in `src/Utils/schema.jl` covers ~80% of flat scalar field boilerplate

## Abstract Type and Sentinel Pattern

- Ten abstract type dimensions for algorithm options; parameterless subtypes use `Type(::Dict, ::CompositeException) = Type()`
- Abstract sentinel type (`NoMarkovChain`, `InflowNone`, `DefaultDuality`, etc.) is the default for optional fields; `Union{T,Nothing}` reserved for fields where absence should error
- `OutOfSampleValidation` is the sole `Union{T, Nothing}` field on `SDDPEngine`; all other optional engine fields use concrete sentinel defaults
- `__kind_factory!` resolves `{"kind": "TypeName", "params": {...}}` to Julia objects; no registration needed

## SDDPEngine Field Count History

- After Epic 05: 6 fields (`policy`, `simulation`, `diagnostics`, `solver`, `inflow_non_negativity`, `validation`)
- After Epic 09: 7 fields — `debug::DebugConfig` added as 7th field with all-false defaults
- `SDDPPolicyTaskDefinition`: 9 fields — `logging::TrainingLogConfig` added as 9th field in Epic 09
- `SDDPPolicyTaskArtifact`: 2 fields — `training_log::Union{TrainingLog,Nothing}` added as 2nd field in Epic 09

## Julia Module Export and Documenter.jl Integration (Epic 10)

- `export` in a submodule does NOT bind the symbol in the parent module's namespace; use explicit `using .SubModule: Symbol` in `src/SDDPlab.jl` for every exported symbol that must appear in `@docs` blocks
- `makedocs(modules = [...])` must list all submodules explicitly: `SDDPlab`, `SDDPlab.Lab`, `SDDPlab.System`, `SDDPlab.Scenarios`, `SDDPlab.StochasticProcess`, `SDDPlab.Engines`; see `docs/make.jl` lines 10-17
- `@docs` blocks resolve against the modules list; use unqualified names after adding parent-module imports
- `warnonly = true` in `makedocs` is required when parallel agents or incremental development leaves intermediate broken cross-references; without it, non-fatal warnings cause build failure
- `Documenter.jl` `@ref` cross-references only work for symbols documented on a page via a `@docs` block; referencing undocumented symbols degrades to a warning (with `warnonly = true`) not a broken link
- New submodule registration requires two steps: (1) add to `makedocs(modules = [...])` in `docs/make.jl`; (2) add `using .NewModule: NewType` in `src/SDDPlab.jl`

## Inline JSONC Entity Arrays (Epic 10)

- `JSON.jl` parses inline `"entities": [...]` arrays as `Vector{Any}` not `Vector{Dict{String,Any}}`; explicit conversion required in `src/System/System.jl` lines 464-474 before downstream validators run
- CSV-loaded entities do not need this conversion (DataFrame row iteration produces typed Dicts)
- Mixed-mode configs (some entities from CSV, some inline) are valid and rely on the same `__cast_system_entity_from_file!` dispatcher

## Observability Layer (Epic 09)

- `SDDP.train()` returns `nothing`; training results are on `model.policy_graph.most_recent_training_results`; access always wrapped in `try-catch @warn`; see `src/Engines/sddp/train.jl`
- `TrainingLogConfig` under `"policy"` sub-dict; `DebugConfig` at engine top level; both default to no-op when key is absent
- All convergence analysis functions are pure (no side effects); file I/O only in `save_policy.jl` thin wrappers; see `src/Engines/sddp/convergence_analysis.jl`
- `__sanitize_for_json` converts `NaN`/`Inf` to `nothing` before JSON serialization; see `src/Engines/sddp/save_policy.jl` lines 193-207
- `SDDP.deterministic_equivalent` fails on trained models (cuts already added); must be called on a freshly-built model
- When `log_file == ""`, do not pass the kwarg to `SDDP.train()`; passing empty string creates an empty file

## Output File Registration Pattern

- Every new output file: add filename constant to `src/Lab/files.jl`, export from `src/Lab/Lab.jl`, add `__write_*` function in `save_policy.jl` with `Union{T,Nothing}` guard returning early on `nothing`
- Per-symbol docstrings on `const` declarations enable REPL `?SYMBOL` help and Documenter `@docs` blocks; pattern: `"One-line description." \n CONST_NAME = value`; see `src/Lab/variables.jl`

## Orchestration Layer (Epic 08)

- New orchestration code uses plain `include()` into `SDDPlab` scope, not a Julia submodule; see `src/Experiments/Experiments.jl`
- All pipeline calls inside orchestration functions use `Base.invokelatest(fn, args...)` to avoid world-age errors; see `src/Experiments/runner.jl`
- Always `deepcopy(base_dict)` before each config run; `Study()` mutates its input dict in-place
- `JSON.jl` does NOT sort keys; deterministic hashing requires custom `_write_json_sorted` recursive serializer; see `src/Experiments/reproducibility.jl`

## Block Variable Dimensionality (Epic 06)

- All power/flow decision variables are permanently 2D `[entity, block]` even for K=1; `src/Engines/sddp/build.jl`
- State variables (`STORED_VOLUME`) and inflow variables are always 1D; `BLOCK_STORAGE` is a regular JuMP variable, NOT `SDDP.State`
- `BlockConfig` lives on `ScenariosData` as a required field; `default_block_config()` returns empty blocks

## Stochastic Process Architecture (Epics 01-07)

- Three process types: `Naive`, `AutoRegressive` (PAR(p)), `VectorAutoRegressive` (VAR(p))
- VAR flat indexing: `index_t[n] = (n-1) * max_lag + 1`; recurrence in normalized `(X-mu)/sigma` space
- `InflowScenarios.stochastic_process` is `Dict{Int, AbstractStochasticProcess}`; legacy JSONs wrapped in `Dict(1 => process)` at parse time
- Markov: `SDDP.MarkovianGraph(mc.transition_matrices)` bypasses SDDPlab `Graph`; per-state SAA uses prime offset `seed + (state - 1) * 7919`
- Markov chain requires N-1 transition matrices for N stages: first matrix is `[1 x num_states]` root distribution, subsequent are `[num_states x num_states]` row-stochastic transitions

## Scaling System (6 Touch Points)

- Every new variable symbol requires 6 touch points: `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, `map_variable_entities`
- `no_scaling_config()` must include every new symbol; missing symbols cause `KeyError` at simulation output time
- Validation output maps in `validate.jl` are a separate copy from simulation output maps; update both

## Parallel Agent Coordination (Epic 10)

- Parallel agents that all modify the same file (e.g., `docs/make.jl`) will overwrite each other; the last writer wins; designate one agent as the sole owner of shared files or sequence the shared-file step after all parallel work is complete
- The `warnonly = true` workaround allows incomplete intermediate documentation states to not fail the build, enabling parallel documentation workflows at the cost of non-fatal warnings requiring manual inspection

## Testing Conventions

- Never add tests to large existing files (SIGABRTs observed with `test-engines.jl`); always create new test files
- Never run `test-main` without 360000ms Bash timeout; use `TEST_FILTER` with 120000ms (unit) or 180000ms (integration)
- GLPK is NOT thread-safe; use HiGHS for any test that exercises `SDDP.Threaded()`
- `mktempdir() do tmpdir ... end` for all integration tests that write output files
- Use `example/1dtoy` as the base study; set `max_iterations: 3`, `num_simulated_series: 2-5` to keep tests fast
- Mock `TrainingLog` objects (using `TrainingLogEntry` struct directly) allow unit testing all convergence analysis functions without running SDDP
- `@suppress` from `Suppressor.jl` silences SDDP.jl console output in integration tests
- New tutorial examples should be validated end-to-end with Bash timeout 180000ms; experiment and sensitivity examples require additional `run_experiment` / `run_sensitivity` calls
