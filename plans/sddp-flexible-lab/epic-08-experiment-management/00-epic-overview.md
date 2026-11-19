# Epic 08: Experiment Management

## Goal

Build experiment management capabilities that allow users to compare multiple algorithm configurations, run automated sensitivity analyses, and ensure reproducibility of results. The experiment module is a thin orchestration layer on top of the existing `read_study -> build -> train -> simulate -> save_*` pipeline. It does NOT modify the core SDDP pipeline.

## Primary Agent

`hpc-julia-developer` -- These tickets are Julia infrastructure work: multi-process orchestration, configuration management, I/O pipelines, DataFrame aggregation, and reproducibility tooling. The `sddp-specialist` reviews to ensure experiment parameters and comparison metrics are SDDP-meaningful.

## Architecture

All experiment management code lives in `src/Experiments/Experiments.jl` module with the following files:

- `types.jl` -- Core structs (ExperimentConfig, ExperimentResult, etc.)
- `merge.jl` -- Deep-merge utility for Dict{String,Any}
- `config.jl` -- JSONC config parsing and validation
- `runner.jl` -- Sequential multi-config experiment execution
- `sensitivity.jl` -- OAT and factorial parameter sweep generation
- `comparison.jl` -- Result aggregation and cross-config comparison
- `reproducibility.jl` -- Environment capture, config hashing, metadata writing

The module imports the SDDPlab public API (`read_study`, `build`, `train`, `simulate`, `save_*`) and orchestrates the pipeline for each configuration variant.

## Scope

### In Scope

- Multi-configuration comparison framework (experiment.jsonc)
- Automated sensitivity analysis (sensitivity.jsonc, OAT and factorial modes)
- Result aggregation and comparison (summary statistics, cross-config DataFrames)
- Reproducibility (seed capture, config hashing, environment snapshots, metadata.json)
- File-based output only (CSV, Parquet)

### Out of Scope

- Plotting/visualization (defer to external tools: R, Python, Julia plotting)
- Database storage
- Web UI or dashboard
- Parallel experiment execution (configs run sequentially)
- Modifications to the core SDDP pipeline

## Tickets

| ID         | Title                                           | Estimate | Agent               | Dependencies     |
| ---------- | ----------------------------------------------- | -------- | ------------------- | ---------------- |
| ticket-034 | Implement multi-configuration experiment runner | 4 pts    | hpc-julia-developer | Epic 07 complete |
| ticket-035 | Add automated sensitivity analysis              | 3 pts    | hpc-julia-developer | ticket-034       |
| ticket-036 | Add result aggregation and comparison tools     | 3 pts    | hpc-julia-developer | ticket-034, 035  |
| ticket-037 | Add reproducibility infrastructure              | 2 pts    | hpc-julia-developer | ticket-034       |

**Total estimate**: 12 points

## Dependencies

- Epic 07 must be complete (all pipeline features available)

## Test Strategy

- All tests in `test/Experiments/` subdirectory
- Use `TEST_FILTER="test-experiment"` or `TEST_FILTER="test-sensitivity"` etc. with 180000ms Bash timeout
- Integration tests use `example/1dtoy` with very low iteration counts (3-5) for fast execution
- Never run `test-main` without 360000ms timeout
