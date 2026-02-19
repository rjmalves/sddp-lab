# Epic 08 Learnings — Experiment Management

## Patterns Established

- **Plain include into parent module scope**: `src/Experiments/Experiments.jl` is not a Julia submodule (`module Experiments ... end`). Instead it is a bare file that uses `include(...)` to pull sibling files directly into the `SDDPlab` module scope. This is because runner.jl must call `Study()`, `build()`, `train()`, `simulate()`, `save_simulation()`, and `save_policy()` which are all defined in `SDDPlab` — not in any sub-namespace. Every future orchestration layer that wraps the public API should use the same pattern. See `src/Experiments/Experiments.jl`.

- **`Base.invokelatest` for world-age safety in orchestration layers**: Every call to `Study()`, `build()`, `train()`, `simulate()`, `save_simulation()`, `save_policy()`, `capture_environment()`, and `write_run_metadata()` inside `_run_single_config` is wrapped in `Base.invokelatest(...)`. This is mandatory because test harnesses load solver packages (e.g. HiGHS) after SDDPlab is precompiled, causing world-age mismatches that crash with `MethodError: no method matching`. Any future function that calls the public pipeline from an orchestration context must use `invokelatest`. See `src/Experiments/runner.jl` lines 137-180.

- **Deep merge before Study construction**: Engine overrides are applied to the raw `Dict{String,Any}` from `main.jsonc` via `deep_merge(base_engine_params, overrides)` before passing the merged dict to `Study(dict, e)`. This means the entire existing Study construction pipeline (validators, `__kind_factory!`, constructor chain) validates the merged result automatically — no duplicate validation needed. See `src/Experiments/merge.jl` and `src/Experiments/runner.jl` lines 99-127.

- **`deepcopy` before each config run to prevent dict pollution**: The `Study` constructor mutates the input dict in place (builds internals, resolves kinds, fills defaults). Without `deepcopy(base_dict)`, the second config run in an experiment sees a corrupted dict from the first run. Always call `deepcopy` on the base dict before applying overrides. See `src/Experiments/runner.jl` line 101.

- **`try-finally` for working directory management**: `read_jsonc` and `Study()` resolve file paths relative to the current working directory. The runner uses explicit `cd(base_study_path)` / `cd(original_pwd)` pairs with outer `try-catch` (not `try-finally`) to guarantee `pwd()` is restored even on exception. The outer catch at lines 186-192 of `runner.jl` always calls `cd(original_pwd)` before returning the failure `ExperimentResult`. Use this pattern in all future orchestration that involves `cd()`.

- **Deterministic config hashing via recursive key sort**: `JSON.jl` does NOT sort dict keys during serialization — insertion order varies across Julia dict instances holding identical data. `hash_config` in `src/Experiments/reproducibility.jl` implements `_canonical_json` / `_write_json_sorted` which recursively sorts all `Dict` keys before serialization, then computes `SHA.sha256`. This is the only correct approach for deterministic hashing of Julia dicts. See `src/Experiments/reproducibility.jl` lines 232-263.

- **Deliberate logic duplication for module boundary isolation**: `_compute_comparison_statistics` in `src/Experiments/comparison.jl` (lines 322-344) is an intentional copy of `_compute_validation_statistics` in `src/Engines/sddp/validate.jl`. The Experiments module does not depend on SDDP engine internals — duplicating the 10-metric statistical summary (mean, std, CI, percentiles) is preferable to creating a cross-module dependency. The same applies to the t-quantile lookup table (`_comparison_t_quantile_95`).

- **`STAGE_COST` not `TOTAL_COST` for policy comparison**: When aggregating simulation results, per-scenario total cost is computed by summing `STAGE_COST` rows across all stages (not `TOTAL_COST`). `TOTAL_COST` at each stage includes a future cost estimate and double-counts across stages. The correct field is `STAGE_COST`. See `src/Experiments/comparison.jl` lines 233-250 and the comment at line 234.

- **Config name collision resolution with `_unique_name`**: Auto-generated sensitivity config names (from `_sanitize_config_name`) can collide (e.g., two floats that round to the same string). `_unique_name` maintains a `seen_names::Dict{String,Int}` counter and appends `_N` suffixes, also tracking the suffixed names to prevent secondary collisions. See `src/Experiments/sensitivity.jl` lines 544-557.

## Architectural Decisions

- **Experiments module uses plain include, not a Julia submodule**: Considered wrapping in `module Experiments ... end`, but that would require re-exporting or qualifying every call to the public pipeline (`SDDPlab.build`, etc.) and would break the simple `Study(dict, e)` constructor call. Decision: plain include into `SDDPlab` scope. Trade-off accepted: all experiment-internal names (`deep_merge`, `_run_single_config`, etc.) are visible in the `SDDPlab` namespace and could shadow names from other modules. Mitigation: internal helpers use `_` prefix convention.

- **Sequential config execution, not parallel**: The epic overview and tickets explicitly scope out parallel experiment execution. Each config runs in the same Julia process sequentially. Rationale: parallel execution would require multi-process coordination, solver thread safety guarantees, and output directory locking — all out of scope.

- **Metadata write is non-fatal by design**: `write_run_metadata` is wrapped in `try-catch` inside `_run_single_config` (lines 171-180 of runner.jl). A metadata write failure logs `@warn` but never aborts a successfully-completed experiment run. This is a deliberate resilience decision: the scientific result is more important than the provenance metadata.

- **`experiment_summary.csv` timing is the source of truth for comparison**: `aggregate_experiment_results` reads timing from `experiment_summary.csv`. If that file is absent, timing defaults to `NaN`. This avoids requiring comparison to depend on the runner having been invoked in a specific way — comparison works on any directory that contains config subdirectories with `operation_system.csv`.

- **Sensitivity summary metadata is reconstructed, not stored**: `_write_sensitivity_summary` in `sensitivity.jl` reconstructs which `(parameter_label, parameter_value)` pair each config came from by re-running the same naming logic as `_generate_oat_configs` / `_generate_factorial_configs` with a fresh `seen_names` counter. Considered storing this mapping in the `SensitivityResult` struct, but reconstruction was simpler and guaranteed consistency.

## Files and Structures Created

- `src/Experiments/Experiments.jl` — Entry point; plain `include()` list for all experiment subfiles; no module wrapper. Included after `study.jl` in `src/SDDPlab.jl` line 13.
- `src/Experiments/types.jl` — `ExperimentConfig` (4 fields) and `ExperimentResult` (6 fields) structs.
- `src/Experiments/merge.jl` — `deep_merge(base, override)::Dict{String,Any}`; pure function, no mutation of inputs.
- `src/Experiments/config.jl` — `read_experiment_config(path)::ExperimentConfig`; JSONC parsing with `CompositeException` accumulation; config name regex `^[a-zA-Z0-9_-]+$`.
- `src/Experiments/runner.jl` — `run_experiment(config_path)`, `_run_single_config(...)`, `_prepare_output_dir(...)`, `_extract_seeds(...)`, `_write_summary(...)`; all pipeline calls use `Base.invokelatest`.
- `src/Experiments/sensitivity.jl` — `SensitivityParameter`, `SensitivityConfig`, `SensitivityResult` structs; `read_sensitivity_config`, `run_sensitivity`, `_resolve_path`, `_set_path!`, `_generate_oat_configs`, `_generate_factorial_configs`, `_sanitize_config_name`, `_unique_name`.
- `src/Experiments/comparison.jl` — `ConfigSummary`, `ComparisonResult` structs; `aggregate_experiment_results`, `compare_configs`, `write_comparison`; `_load_total_costs` (loads `operation_system.csv`/`.parquet`, filters `STAGE_COST`, sums per scenario); `_compute_comparison_statistics` (10-metric dict).
- `src/Experiments/reproducibility.jl` — `EnvironmentSnapshot` struct; `capture_environment`, `hash_config`, `write_run_metadata`, `verify_reproducibility`; `_canonical_json` / `_write_json_sorted` for sorted-key serialization.
- `test/Experiments/test-experiment-runner.jl` — Unit tests for `deep_merge` and `read_experiment_config`; integration tests for `run_experiment` (2 configs, 1 valid + 1 invalid, overwrite guard).
- `test/Experiments/test-sensitivity.jl` — Unit and integration tests for OAT and factorial sensitivity.
- `test/Experiments/test-comparison.jl` — Unit and integration tests for `aggregate_experiment_results` and `write_comparison`.
- `test/Experiments/test-reproducibility.jl` — Unit tests for `hash_config`, `capture_environment`, `verify_reproducibility`, `write_run_metadata`; integration tests for metadata presence and deterministic hash.

## Conventions Adopted

- **Internal helper prefix `_`**: All non-exported helpers in the Experiments module use a leading underscore (`_run_single_config`, `_prepare_output_dir`, `_extract_seeds`, `_write_summary`, `_resolve_path`, `_set_path!`, `_sanitize_config_name`, `_unique_name`, `_load_total_costs`, `_canonical_json`, etc.). Exported symbols have no prefix. This convention distinguishes public API from implementation detail within the `SDDPlab` flat namespace.

- **`CompositeException` accumulation in config parsers**: Both `read_experiment_config` and `read_sensitivity_config` accumulate all validation errors before throwing, consistent with every other constructor in the codebase. They `throw(e)` at the end of each logical validation block when errors exist, rather than immediately on each error.

- **Absolute path normalization in config parsers**: All path fields (`base_study`, `output_dir`) are resolved to absolute paths at parse time using `abspath` / `normpath(joinpath(experiment_dir, raw_path))`. The experiment directory is `dirname(abspath(config_path))`. Downstream code never deals with relative paths.

- **`mktempdir` for all experiment integration tests**: Tests use `mktempdir() do tmpdir ... end` blocks so that all output files are cleaned up automatically. The `example/1dtoy` case is used as the base study for all integration tests, with `max_iterations: 3` and `num_simulated_series: 2-5` to keep runtime under a few seconds. See `test/Experiments/test-experiment-runner.jl` line 9 for the `_example_dir()` helper.

- **`TEST_FILTER` scoping**: Each test file is designed to run independently under `TEST_FILTER="test-experiment-runner"`, `TEST_FILTER="test-sensitivity"`, `TEST_FILTER="test-comparison"`, or `TEST_FILTER="test-reproducibility"`. Never run without a filter — integration tests invoke the full SDDP pipeline.

## Surprises and Deviations

- **World-age error required `invokelatest` throughout**: The ticket's implementation guide suggested calling `Study(working_dict, e2)` directly. In practice, calling functions defined earlier in the same module's compilation phase from code loaded later (the Experiments files are included after `study.jl`) triggers Julia's world-age restriction when the call happens from a test harness that loaded packages post-precompilation. Every public pipeline call in `_run_single_config` was wrapped in `Base.invokelatest`. This was not anticipated in the ticket. See `src/Experiments/runner.jl` lines 133-180.

- **JSON key ordering is NOT deterministic in JSON.jl**: The ticket's implementation guide stated "Note: JSON.json sorts keys by default in Julia's JSON.jl. Verify this." Verification showed this is false — JSON.jl preserves insertion order, which is non-deterministic across Julia `Dict` instances. The implementation added a custom `_write_json_sorted` recursive serializer rather than relying on `JSON.json`. See `src/Experiments/reproducibility.jl` lines 232-265.

- **`TOTAL_COST` vs `STAGE_COST` clarification**: The ticket noted "verify this with the reviewer" for the correct variable to use for total cost. The implementation resolved this by filtering `STAGE_COST` rows and summing across stages. `TOTAL_COST` (which includes future cost estimates) is explicitly excluded with a comment in `src/Experiments/comparison.jl` line 234.

- **Sensitivity summary metadata reconstruction**: The ticket suggested storing `(param_label, param_value)` alongside each `ExperimentResult`. The implementation instead rebuilds this mapping in `_write_sensitivity_summary` by replaying the same config generation logic. This avoids adding metadata fields to `ExperimentResult` (which is also used by the non-sensitivity `run_experiment` path).

- **`read_sensitivity_config` name differs from ticket spec**: The ticket specified `run_sensitivity` reads its own config and did not explicitly name the parser function. The implementation named it `read_sensitivity_config` (exported from `SDDPlab`) to match the `read_experiment_config` naming convention. `SensitivityConfig`, `SensitivityParameter`, and `SensitivityResult` are all exported.

## Recommendations for Future Epics

- When any future module needs to call `build`, `train`, `simulate`, or any other function defined in `src/study.jl`, use the same plain-include-into-SDDPlab pattern established in `src/Experiments/Experiments.jl` and wrap all calls with `Base.invokelatest(...)`. Do not create a submodule that would require qualifying these names.
- The `_extract_seeds` helper in `src/Experiments/runner.jl` (lines 204-223) accesses `study.inputs.files` and `study.engine.validation` directly. If the `Study` struct fields change in future epics, this helper must be updated.
- `aggregate_experiment_results` in `src/Experiments/comparison.jl` relies on `operation_system.csv` having a long-format `variable_name` column with `STAGE_COST` rows. If the simulation output format changes (e.g., column renames in `save_simulation.jl`), `_load_total_costs` must be updated in sync.
- For the observability epic (epic-09): training progress monitoring will likely need `invokelatest` for the same world-age reasons encountered here; plan for this proactively rather than discovering it during debugging.
- Sensitivity analysis config names are truncated to 60 characters and sanitized to `[a-z0-9_-]`. Dict-valued parameter sweep values (e.g., full `{"kind": "CVaR", "params": {...}}`) serialize to long strings; the 60-char truncation can cause collisions. The `_unique_name` mechanism handles this, but config names in summary CSVs may be cryptic. Consider adding a `label_suffix` field to `SensitivityParameter` in future refinements.
