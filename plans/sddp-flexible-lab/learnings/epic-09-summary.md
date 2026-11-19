# Accumulated Learnings Summary — Epics 01-09

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

## Observability Layer (Epic 09)

- `SDDP.train()` returns `nothing`; training results are on `model.policy_graph.most_recent_training_results` (on `PolicyGraph`, not `Model`); access always wrapped in `try-catch @warn`; see `src/Engines/sddp/train.jl`
- `TrainingLogConfig` under `"policy"` sub-dict; `DebugConfig` at engine top level; both default to no-op when key is absent
- All convergence analysis functions are pure (no side effects); file I/O only in `save_policy.jl` thin wrappers; see `src/Engines/sddp/convergence_analysis.jl`
- `__sanitize_for_json` (recursive Dict/Vector/Float64/fallback multi-method) converts `NaN`/`Inf` to `nothing` before JSON serialization; see `src/Engines/sddp/save_policy.jl` lines 193-207
- `Lab.debug` returns immediately when both `write_subproblems` and `deterministic_equivalent` are false; never wired into automatic pipeline
- `SDDP.write_subproblem_to_file` takes `SDDP.Node` objects, NOT node IDs; iterate `model.policy_graph.nodes` dict to get `(node_id, node)` pairs
- `SDDP.deterministic_equivalent` fails on trained models (cuts already added); must be called on a freshly-built model; errors captured in `debug_summary.json`
- `_format_extension`: `"mof" -> ".mof.json"`, `"lp" -> ".lp"`, `"mps" -> ".mps"`; validated at construction time via `AssertionError`
- `convergence_report.json` is always JSON regardless of `TaskResultsFormat`; tabular files (training_log, convergence_analysis) follow the format
- When `log_file == ""`, do not pass the kwarg to `SDDP.train()`; passing empty string creates an empty file

## Output File Registration Pattern

- Every new output file: add filename constant to `src/Lab/files.jl`, export from `src/Lab/Lab.jl`, add `__write_*` function in `save_policy.jl` with `Union{T,Nothing}` guard returning early on `nothing`
- Backward compatibility: `__get_model_convergence` (temp-file roundtrip via `SDDP.write_log_to_csv`) retained unchanged; new training_log and convergence_analysis are additive

## Orchestration Layer (Epic 08)

- New orchestration code uses plain `include()` into `SDDPlab` scope, not a Julia submodule; see `src/Experiments/Experiments.jl`
- All pipeline calls inside orchestration functions use `Base.invokelatest(fn, args...)` to avoid world-age errors; see `src/Experiments/runner.jl`
- Always `deepcopy(base_dict)` before each config run; `Study()` mutates its input dict in-place
- `JSON.jl` does NOT sort keys; deterministic hashing requires custom `_write_json_sorted` recursive serializer; see `src/Experiments/reproducibility.jl`
- Use `STAGE_COST` rows (not `TOTAL_COST`) for per-scenario total policy cost; `TOTAL_COST` double-counts future cost estimates

## Block Variable Dimensionality (Epic 06)

- All power/flow decision variables are permanently 2D `[entity, block]` even for K=1; `src/Engines/sddp/build.jl`
- State variables (`STORED_VOLUME`) and inflow variables are always 1D; `BLOCK_STORAGE` is a regular JuMP variable, NOT `SDDP.State`
- `BlockConfig` lives on `ScenariosData` as a required field; `default_block_config()` returns empty blocks

## Stochastic Process Architecture (Epics 01-07)

- Three process types: `Naive`, `AutoRegressive` (PAR(p)), `VectorAutoRegressive` (VAR(p))
- VAR flat indexing: `index_t[n] = (n-1) * max_lag + 1`; recurrence in normalized `(X-mu)/sigma` space
- `InflowScenarios.stochastic_process` is `Dict{Int, AbstractStochasticProcess}`; legacy JSONs wrapped in `Dict(1 => process)` at parse time
- Markov: `SDDP.MarkovianGraph(mc.transition_matrices)` bypasses SDDPlab `Graph`; per-state SAA uses prime offset `seed + (state - 1) * 7919`
- `OutOfSampleValidation` is 6th field on `SDDPEngine` as `Union{T, Nothing}`

## Multiple Dispatch Conventions

- Objective contribution: multiple dispatch on method type avoids if/else chains; `src/Engines/sddp/build.jl` lines 340-385
- Node ID to string: `_node_id_to_string(id::Int)` and `_node_id_to_string(id::Tuple{Int,Int})`; handles linear and Markov graphs transparently; `src/Engines/sddp/debug.jl`

## Scaling System (6 Touch Points)

- Every new variable symbol requires 6 touch points: `compute_scaling_factors`, `apply_scaling`, `_get_variable_unscale_factor`, `no_scaling_config`, `map_variable_output`, `map_variable_entities`
- `no_scaling_config()` must include every new symbol; missing symbols cause `KeyError` at simulation output time
- Validation output maps in `validate.jl` are a separate copy from simulation output maps; update both

## Variable Symbol Registration

- Every new JuMP variable or expression: `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl` + export in `src/Lab/Lab.jl`
- Epics 08-09 added no new JuMP variable symbols

## Testing Conventions

- Never add tests to large existing files (SIGABRTs observed with `test-engines.jl`); always create new test files
- Never run `test-main` without 360000ms Bash timeout; use `TEST_FILTER` with 120000ms (unit) or 180000ms (integration)
- GLPK is NOT thread-safe; use HiGHS for any test that exercises `SDDP.Threaded()`
- `mktempdir() do tmpdir ... end` for all integration tests that write output files
- Use `example/1dtoy` as the base study; set `max_iterations: 3`, `num_simulated_series: 2-5` to keep tests fast
- Mock `TrainingLog` objects (using `TrainingLogEntry` struct directly) allow unit testing all convergence analysis functions without running SDDP
- `@suppress` from `Suppressor.jl` silences SDDP.jl console output in integration tests
