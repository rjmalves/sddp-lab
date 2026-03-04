# ticket-036 Add Result Aggregation and Comparison Tools

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify comparison metrics are statistically sound for SDDP)

## Context

### Background

After tickets 034 and 035, users can run multi-configuration experiments and sensitivity analyses. The outputs are saved in per-configuration subdirectories, each containing the standard simulation CSV files (`operation_buses.csv`, `operation_hydros.csv`, `operation_system.csv`, etc.) plus `experiment_summary.csv` or `sensitivity_summary.csv`. However, comparing results across configurations requires manual loading and joining of these files.

This ticket creates aggregation and comparison utilities that read results from multiple configuration directories, compute per-configuration summary statistics, and produce cross-configuration comparison DataFrames and CSV files. The focus is on producing structured tabular data suitable for external analysis (R, Python, Julia plotting libraries) -- this ticket does NOT add plotting/visualization.

### Relation to Epic

This is the third ticket in Epic 08. It consumes the output structure established by ticket-034 (experiment runner) and optionally enriched by ticket-035 (sensitivity analysis). The reproducibility ticket (ticket-037) adds metadata to the results this ticket aggregates.

### Current State

After tickets 034-035:

- Experiment results are saved in `<output_dir>/<config_name>/` with standard simulation CSVs
- `experiment_summary.csv` has columns: config_name, success, train_time_s, simulate_time_s, error
- `sensitivity_summary.csv` adds columns: parameter_label, parameter_value
- The existing `_compute_validation_statistics` in `src/Engines/sddp/validate.jl` (lines 101-129) computes mean, std, CI, percentiles from simulation total costs -- this pattern should be reused
- Simulation output files follow a standard format: stage, variable_name, entity_id, scenario columns (wide format with scenarios as columns)

## Specification

### Requirements

1. Create `src/Experiments/comparison.jl` with comparison utility functions
2. Implement `aggregate_experiment_results(output_dir::String)::ComparisonResult` that:
   a. Scans all subdirectories in `output_dir` for valid experiment output
   b. For each config directory, loads `operation_system.csv` (or `.parquet`) to extract per-scenario total costs
   c. Computes summary statistics per config: mean cost, std, 95% CI, p05, p50, p95, min, max (reusing the same metric set as `_compute_validation_statistics`)
   d. Returns a `ComparisonResult` struct with per-config summaries
3. Implement `write_comparison(result::ComparisonResult, path::String, format::TaskResultsFormat)` that writes:
   a. `comparison_summary.csv`: one row per configuration with columns config_name, mean_cost, std_cost, ci_lower_95, ci_upper_95, p05_cost, p50_cost, p95_cost, min_cost, max_cost, train_time_s, simulate_time_s
   b. `comparison_costs.csv`: long-format DataFrame with columns config_name, scenario, total_cost (all scenarios from all configs in one table for easy plotting)
4. Implement `compare_configs(output_dir::String, config_names::Vector{String})` that aggregates only the specified configs (useful when the user wants to compare a subset)
5. All functions work with both CSV and Parquet output formats (auto-detect based on file extension in the config directory)

### Inputs/Props

- `output_dir::String` -- path to the experiment output directory containing config subdirectories
- `config_names::Vector{String}` -- optional filter for specific configs to compare
- Output format follows `TaskResultsFormat` (CSVFormat or ParquetFormat)

### Outputs/Behavior

- `ConfigSummary` struct:
  - `config_name::String`
  - `statistics::Dict{String,Float64}` (same keys as `_compute_validation_statistics`)
  - `train_time_s::Float64`
  - `simulate_time_s::Float64`
  - `num_scenarios::Int`
- `ComparisonResult` struct:
  - `summaries::Vector{ConfigSummary}`
  - `output_dir::String`
- `comparison_summary.csv` is a wide-format table with one row per configuration
- `comparison_costs.csv` is a long-format table with all scenarios from all configs

### Error Handling

- Config directory missing expected output files: skip with a warning, do not fail the entire aggregation
- `experiment_summary.csv` missing: infer config names from subdirectory names, set timing to NaN
- Mismatched scenario counts across configs: include all scenarios, note the count per config in the summary
- Empty config directory: skip with a warning

## Acceptance Criteria

- [ ] C1: Given an experiment output directory with 2 config subdirectories each containing `operation_system.csv`, when `aggregate_experiment_results` is called, then a `ComparisonResult` with 2 `ConfigSummary` entries is returned, each with valid statistics (mean, std, CI, percentiles)
- [ ] C2: Given a `ComparisonResult`, when `write_comparison` is called, then `comparison_summary.csv` contains one row per config with all statistical columns
- [ ] C3: Given a `ComparisonResult`, when `write_comparison` is called, then `comparison_costs.csv` contains scenario-level total costs from all configs in long format
- [ ] C4: Given a config directory that is missing `operation_system.csv`, when `aggregate_experiment_results` is called, then that config is skipped with a `@warn` and the remaining configs are still aggregated
- [ ] C5: Given `compare_configs(output_dir, ["config_a"])`, when only `config_a` is in the output, then only `config_a` appears in the result

## Implementation Guide

### Suggested Approach

1. Create `src/Experiments/comparison.jl` with:

   ```julia
   struct ConfigSummary
       config_name::String
       statistics::Dict{String,Float64}
       train_time_s::Float64
       simulate_time_s::Float64
       num_scenarios::Int
   end

   struct ComparisonResult
       summaries::Vector{ConfigSummary}
       output_dir::String
   end
   ```

2. Implement `_load_total_costs(config_dir::String)::Vector{Float64}`:
   - Look for `operation_system.csv` or `operation_system.parquet`
   - Load the file as a DataFrame
   - Filter rows where `variable_name == "TOTAL_COST"`
   - Each scenario column (named "1", "2", ...) contains per-stage costs
   - Sum across stages per scenario to get total costs
   - The existing simulation output format has columns: stage, variable_name, entity_id, then scenario columns (1, 2, 3, ...)

3. Implement `_compute_config_statistics(total_costs::Vector{Float64})::Dict{String,Float64}`:
   - Reuse the same metric computation as `_compute_validation_statistics` in `src/Engines/sddp/validate.jl` lines 101-129
   - Either extract that function to a shared location, or duplicate the logic (duplication is acceptable since this is a different module with different dependencies)

4. Implement `_read_experiment_summary(output_dir)` to load timing data from `experiment_summary.csv`.

5. `aggregate_experiment_results` scans subdirectories, calls `_load_total_costs` and `_compute_config_statistics` for each, combines with timing from the summary CSV.

6. `write_comparison` writes the two output files using the existing `Lab.get_writer` / `Lab.get_extension` pattern.

### Key Files to Create/Modify

| File                                  | Action | Description                                                                                                |
| ------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------- |
| `src/Experiments/comparison.jl`       | Create | `ConfigSummary`, `ComparisonResult`, `aggregate_experiment_results`, `write_comparison`, `compare_configs` |
| `src/Experiments/Experiments.jl`      | Modify | Add `include("comparison.jl")` and exports                                                                 |
| `src/SDDPlab.jl`                      | Modify | Add comparison exports                                                                                     |
| `test/Experiments/test-comparison.jl` | Create | Tests for aggregation and comparison                                                                       |

### Patterns to Follow

- Reuse the statistical computation pattern from `_compute_validation_statistics` in `src/Engines/sddp/validate.jl` (mean, std, CI, percentiles)
- Use `DataFrames.jl` for loading and manipulating CSVs (already a dependency)
- Use `CSV.File` for loading simulation CSVs (same approach as `read_csv` in `src/Utils/reading-utils.jl`)
- Use `Lab.get_writer` / `Lab.get_extension` for output format handling
- Follow the `__variable_exists_in_sim` guard pattern: check for file existence before loading

### Pitfalls to Avoid

- **Simulation output format**: The scenario columns are named "1", "2", etc. as strings after the `stack` + `rename!` transformation in `save_simulation.jl`. When reading them back, they are string columns. Parse to Float64 carefully.
- **TOTAL_COST variable**: In the simulation output, `TOTAL_COST` is stored per-stage. The total cost for a scenario is the SUM across all stages. Do NOT take just the last stage.
- **Stage cost vs TOTAL_COST**: In the SDDP.jl output, `TOTAL_COST` at each stage already includes both stage cost and future cost estimate. The true total cost for policy comparison is the SUM of `STAGE_COST` across stages (not TOTAL_COST which double-counts future costs). Verify this with the reviewer.
- **Format detection**: Check for `.csv` first, then `.parquet`. Do NOT assume CSV.
- **Large files**: Use `CSV.File` (lazy loading) rather than reading entire files into memory for very large experiments.

## Testing Requirements

### Unit Tests

- `_compute_config_statistics` returns correct mean, std, CI for a known vector of costs
- `_load_total_costs` correctly parses a mock `operation_system.csv` with known values
- `ConfigSummary` and `ComparisonResult` construction

### Integration Tests

- Run a 2-config experiment on `example/1dtoy` (max_iterations: 3, num_simulated_series: 10), then call `aggregate_experiment_results` on the output directory and verify statistics are non-NaN and the comparison CSVs are written correctly
- **Use `TEST_FILTER="test-comparison"` and 180000ms Bash timeout**

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-034 (experiment runner must produce output directories), ticket-035 (optional -- comparison works without sensitivity, but sensitivity summary enriches comparison)
- **Blocks**: ticket-037

## Effort Estimate

**Points**: 3
**Confidence**: High
