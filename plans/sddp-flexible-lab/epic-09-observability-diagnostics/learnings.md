# Epic 09 Learnings — Observability and Diagnostics

## Patterns Established

### TrainingLog capture via try-catch on PolicyGraph

After `SDDP.train()` returns (it returns `nothing`), the structured training results live on `model.policy_graph.most_recent_training_results`, not on `model` itself and not on a return value. The conversion from `SDDP.Log` entries to `TrainingLogEntry` is wrapped in `try-catch` with `@warn` and degrades to `nothing` so that version incompatibilities in `SDDP.jl` do not crash the pipeline. See `src/Engines/sddp/train.jl`, function `__capture_training_log`.

### Pure analysis functions with no side effects

All convergence analysis functions (`compute_gap_trajectory`, `compute_convergence_rate`, `detect_bound_stationarity`, `generate_convergence_report`) are defined as pure functions that take `TrainingLog` as input and return data structures. File I/O is performed exclusively in `save_policy.jl` by thin wrappers (`__write_convergence_analysis`, `__write_convergence_report`). This separation makes the functions independently testable with mock data without running SDDP. See `src/Engines/sddp/convergence_analysis.jl`.

### NaN sanitization before JSON serialization

`Float64` values `NaN` and `Inf` are valid Julia but invalid JSON. A recursive `__sanitize_for_json` multi-method converts them to `nothing` (JSON null) before writing `convergence_report.json`. The four methods cover `Dict`, `Vector`, `Float64`, and a catch-all fallback. See `src/Engines/sddp/save_policy.jl` lines 193-207.

### Early-return guard for opt-in debug operations

`Lab.debug` checks `!config.write_subproblems && !config.deterministic_equivalent` at the top and returns immediately as a no-op when both are false. This avoids creating the `debug/` directory or any side effects when the feature is disabled (the default). See `src/Engines/sddp/debug.jl` lines 46-52.

### \_format_extension mapping for subproblem file formats

The mapping from the configuration string `"mof"`, `"lp"`, `"mps"` to the corresponding file extension (`.mof.json`, `.lp`, `.mps`) is centralized in `_format_extension(fmt::String)`. The default fallback is `.mof.json` for unknown inputs. See `src/Engines/sddp/debug.jl` lines 6-11.

### Multiple-dispatch node ID to string conversion

`_node_id_to_string` has two methods: one for `Int` (returns `string(id)`) and one for `Tuple{Int,Int}` (returns `"$(id[1])_$(id[2])"`). This handles both standard linear graphs and Markov graphs transparently without if/else. See `src/Engines/sddp/debug.jl` lines 14-29.

### convergence_report.json always written as JSON regardless of format

The `TaskResultsFormat` (CSV or Parquet) controls tabular output files. The convergence report is always written as JSON because it is a nested Dict, not a tabular structure. The filename constant `POLICY_CONVERGENCE_REPORT_OUTPUT_FILENAME` is defined in `src/Lab/files.jl` and the extension `.json` is hardcoded in `save_policy.jl` line 179.

## Architectural Decisions

### DebugConfig added to SDDPEngine as the 7th field, not as an optional outer-level key

Decision: `debug::DebugConfig` (a concrete struct, not `Union{T,Nothing}`) is always present on `SDDPEngine` with all-false defaults when the `"debug"` key is absent from the JSONC config.
Rejected: `Union{DebugConfig,Nothing}` with `nothing` as the absent-key default, which would require nil-checks at every call site.
Rationale: The all-false defaults make `Lab.debug` a no-op without any nil checks. Consistent with how `DiagnosticsConfig` and `SolverConfig` handle optional-but-always-present configuration. See `src/Engines/Engines.jl` line 265 and `src/Engines/sddp/input.jl` function `__build_debug!`.

### DebugConfig not wired into the automatic pipeline

Decision: `Lab.debug` is exposed through `study.jl` as an explicit call (`SDDPlab.debug(study, model, path)`) and is never called by the Experiments runner or any automatic pipeline step.
Rejected: Inserting a debug step between build and train in the pipeline.
Rationale: Writing subproblem files and the deterministic equivalent can be very slow and produce large files. Debug is a diagnostic tool, not a production artifact.

### SDDPPolicyTaskDefinition grows from 8 to 9 fields with `logging`

Decision: `logging::TrainingLogConfig` is the 9th field of `SDDPPolicyTaskDefinition`, placed under the `"policy"` sub-dict in JSONC (same level as `"convergence"`, `"risk_measure"`, etc.).
Rationale: Logging configuration governs training behavior and belongs with the policy task definition, not at the engine top level. The existing 8-field definition already handled convergence, risk, parallel scheme, sampling, duality, forward pass, cut type, and scaling — logging extends this naturally.

### SDDPPolicyTaskArtifact grows from 1 to 2 fields

Decision: `training_log::Union{TrainingLog,Nothing}` is the second field of `SDDPPolicyTaskArtifact`, alongside `policy::SDDP.PolicyGraph`.
Rationale: The training log is produced by the same `Lab.train()` call that produces the policy graph. Carrying it in the artifact allows `save_policy` to access it without introducing a separate return channel.

### Inline OLS linear regression to avoid new dependencies

Decision: `_simple_linear_slope` implements ordinary least squares slope computation inline in `convergence_analysis.jl` rather than importing `GLM.jl` or `Statistics.linear_regression`.
Rationale: The computation is a single formula (4 lines of arithmetic), and adding a dependency on `GLM.jl` would be disproportionate for this use case. Returns `NaN` for degenerate cases (fewer than 2 points, zero variance in x).

## Files and Structures Created

- `src/Engines/sddp/convergence_analysis.jl` — Four pure analysis functions: `_simple_linear_slope`, `compute_gap_trajectory`, `compute_convergence_rate`, `detect_bound_stationarity`, `generate_convergence_report`. No imports or side effects; operates entirely on `TrainingLog`.
- `src/Engines/sddp/debug.jl` — `Lab.debug(model::SDDPModel, engine::SDDPEngine, path::String)`, `_format_extension`, `_node_id_to_string`. Writes to `debug/` subdirectory.
- `src/Lab/files.jl` — Three new output filename constants: `POLICY_TRAINING_LOG_OUTPUT_FILENAME`, `POLICY_CONVERGENCE_ANALYSIS_OUTPUT_FILENAME`, `POLICY_CONVERGENCE_REPORT_OUTPUT_FILENAME`.
- `test/test-training-log.jl` — Unit and integration tests for `TrainingLogConfig`, `TrainingLog`, `TrainingLogEntry`, and the end-to-end training log capture and save.
- `test/test-convergence-analysis.jl` — Unit tests on mock `TrainingLog` objects and integration tests verifying `convergence_analysis.csv` and `convergence_report.json` are written correctly.
- `test/test-debug.jl` — Unit tests for `DebugConfig` construction and validation, plus integration tests covering mof/lp subproblem writing, node filtering, deterministic equivalent, no-op behavior, and `debug_summary.json` content.

## Conventions Adopted

### Logging kwargs: empty string means "do not pass"

When `TrainingLogConfig.log_file == ""`, the `log_file` kwarg is NOT passed to `SDDP.train()`. Passing an empty string creates an empty file. Guard is `if !isempty(logging.log_file)` before adding to `train_kwargs`. See `src/Engines/sddp/train.jl` lines 36-38.

### Backward compatibility: `__get_model_convergence` not modified

The original `__get_model_convergence` function (which writes `SDDP.write_log_to_csv` to a temp file and reads it back) is retained unchanged. The new `__write_training_log` and `__write_convergence_analysis` functions are additions, not replacements. Both the legacy `convergence.csv` and the new `training_log.csv`/`convergence_analysis.csv` are written on every `save_policy` call.

### Output filename constants in src/Lab/files.jl

All policy output filenames (cuts, convergence, training_log, convergence_analysis, convergence_report) are defined as module-level constants in `src/Lab/files.jl` and exported from `src/Lab/Lab.jl`. This avoids magic strings scattered across `save_policy.jl`.

### `__sanitize_for_json` is exported from `Engines` for testability

The `__sanitize_for_json` helper is accessible as `Engines.__sanitize_for_json` so that tests can verify the sanitization logic directly without needing to call `save_policy`. This was deliberate for the test in `test-convergence-analysis.jl` at line 321.

### SDDP.write_subproblem_to_file takes Node objects, not node IDs

`model.policy_graph.nodes` is a `Dict` mapping node IDs to `SDDP.Node` objects. The iteration in `Lab.debug` is `for (node_id, node) in model.policy_graph.nodes`, so `node` is the `SDDP.Node` directly and is passed to `SDDP.write_subproblem_to_file(node, filename; throw_error=false)`. The node ID is used only for constructing the filename.

## Surprises and Deviations

### `SDDP.deterministic_equivalent` fails on trained models

What was expected: the ticket specification stated that `deterministic_equivalent: true` could be called after build or after train.
What happened: `SDDP.deterministic_equivalent` raises an exception when called on a `PolicyGraph` that has already been trained (cuts have been added). The test `integration-deterministic-equivalent-trained-model-error-captured` in `test/test-debug.jl` documents this behavior explicitly and verifies that the error is captured in `debug_summary.json` rather than propagating. The recommendation in the tests is to call `debug` on a freshly-built (untrained) model when `deterministic_equivalent: true`.

### `print_level` validated as `in_range(0, 2)`, not `in_range(0, 3)`

What was expected: SDDP.jl supports print levels 0-3 based on source code comments.
What happened: The validator in `TRAINING_LOG_CONFIG_SCHEMA` uses `in_range(0, 2)` (inclusive). This is a conservative choice reflecting observed behavior. The validator is in `src/Engines/sddp/input-validators.jl` line 109.

### `subproblem_nodes` is `Vector{Any}` in the schema, not typed

What was expected: nodes would be validated as integers matching the graph node type at construction time.
What happened: `subproblem_nodes` is accepted as `Vector{Any}` to accommodate both `Int` and `Tuple{Int,Int}` node types. Type validation (checking that each element matches the actual graph's node key type) happens implicitly at debug time through the `node_id in config.subproblem_nodes` membership check, not at construction time.

## Recommendations for Future Epics

- When adding new output files to `save_policy`, follow the pattern: add a filename constant to `src/Lab/files.jl`, export it from `src/Lab/Lab.jl`, then add a `__write_*` function in `save_policy.jl` that takes `Union{T,Nothing}` and returns early on `nothing`.
- Any new analysis module (analogous to `convergence_analysis.jl`) should be pure (no side effects) and take domain structs as input. Include it in `src/Engines/sddp.jl` after `validate.jl` but before `debug.jl`.
- When exposing SDDP.jl internals (fields on `PolicyGraph`, structs from `SDDP.Log`), always wrap in `try-catch` — SDDP.jl does not guarantee field-level API stability across minor versions.
- The `DebugConfig` pattern (all-false defaults, early-return no-op guard, errors captured in a summary JSON) is a reusable pattern for any future opt-in diagnostic or export feature.
