# ticket-039 Add Convergence Analysis Tools

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: None

## Context

### Background

After ticket-038, the `SDDPPolicyTaskArtifact` contains a structured `TrainingLog` with per-iteration data: bound values, simulation values, elapsed time, solver calls, and numerical issue flags. This data is the raw material for convergence analysis.

Currently, the only convergence information SDDPlab exposes is the raw convergence CSV written by `save_policy` (via `__get_model_convergence()` in `save_policy.jl`), which contains columns `iteration`, `lower_bound`, `simulation`, `upper_bound`, and `time`. Users must manually inspect this data to assess convergence quality.

This ticket adds post-training convergence analysis functions that operate on the `TrainingLog` struct (from ticket-038) and compute diagnostic metrics: gap trajectory, convergence rate, bound stationarity, and a summary report. The analysis results are saved as structured output files alongside the policy.

### Relation to Epic

This is the second ticket in Epic 09 (Observability and Diagnostics). It builds on the training log infrastructure from ticket-038 to provide automated convergence diagnostics. The metrics computed here are analysis-only -- they do not modify the training process or model.

### Current State

- `SDDPPolicyTaskArtifact` (after ticket-038) contains `training_log::Union{TrainingLog, Nothing}` with fields `status::Symbol` and `iterations::Vector{TrainingLogEntry}`
- `TrainingLogEntry` has fields: `iteration`, `bound`, `simulation_value`, `time`, `total_solves`, `serious_numerical_issue`
- `save_policy.jl` already writes convergence data via `__get_model_convergence()` and the new `__write_training_log` (from ticket-038)
- The Experiments comparison framework in `src/Experiments/comparison.jl` computes a 10-metric statistical summary (mean, std, CI, percentiles) -- a similar pattern can be followed for convergence metrics
- No convergence analysis logic exists anywhere in the codebase

## Specification

### Requirements

1. **New file `src/Engines/sddp/convergence_analysis.jl`** containing pure functions that analyze a `TrainingLog`:

   a. **`compute_gap_trajectory(log::TrainingLog) -> DataFrame`**: For each iteration, compute the relative gap `(simulation_value - bound) / abs(bound)` (or `NaN` when bound is zero). Returns a DataFrame with columns: `iteration`, `bound`, `simulation_value`, `gap_absolute`, `gap_relative`.

   b. **`compute_convergence_rate(log::TrainingLog) -> Dict{String, Float64}`**: Compute metrics that characterize convergence speed:
   - `bound_improvement_rate`: average per-iteration change in bound over the last 50% of iterations
   - `gap_reduction_rate`: linear regression slope of `log(gap_relative)` vs iteration (for iterations where gap > 0)
   - `total_time_seconds`: wall-clock training time
   - `time_per_iteration_mean`: mean time per iteration
   - `time_per_iteration_std`: std of time per iteration
   - `iterations_total`: total number of iterations
   - `final_bound`: bound at last iteration
   - `final_simulation_value`: simulation value at last iteration
   - `final_gap_relative`: relative gap at last iteration

   c. **`detect_bound_stationarity(log::TrainingLog; window::Int=20, threshold::Float64=1e-6) -> Dict{String, Any}`**: Analyze the last `window` iterations to detect bound stagnation:
   - `is_stationary::Bool`: true if the bound range over the window is below `threshold * abs(final_bound)`
   - `stationary_since_iteration::Int`: first iteration in the window where stationarity begins (or 0 if not stationary)
   - `bound_range_in_window::Float64`: max - min of bound values in the window
   - `relative_bound_range::Float64`: bound_range / abs(final_bound)

   d. **`generate_convergence_report(log::TrainingLog) -> Dict{String, Any}`**: Aggregates all the above into a single Dict:
   - `"status"`: training termination status
   - `"convergence_rate"`: output of `compute_convergence_rate`
   - `"bound_stationarity"`: output of `detect_bound_stationarity`
   - `"had_numerical_issues"`: whether any iteration had `serious_numerical_issue == true`
   - `"numerical_issue_iterations"`: list of iteration numbers with issues

2. **Save convergence analysis** alongside policy output:
   - `convergence_analysis.csv` (or `.parquet`): the gap trajectory DataFrame
   - `convergence_report.json`: the convergence report Dict as JSON

3. **Wire into `save_policy`**: Call the analysis functions from `Lab.save_policy` when `artifact.training_log !== nothing`.

### Inputs/Props

All functions take the `TrainingLog` struct from ticket-038 as their primary input. No JSONC configuration needed -- convergence analysis runs automatically whenever a training log is available.

### Outputs/Behavior

- `convergence_analysis.csv`: One row per training iteration with gap metrics
- `convergence_report.json`: Machine-readable summary with convergence rate, stationarity, and issue flags
- Both files are written to the same output directory as other policy files
- If `training_log` is `nothing`, convergence analysis is silently skipped

### Error Handling

- All analysis functions wrap computation in `try-catch` and `@warn` on failure, returning empty/default results rather than aborting
- Division by zero in gap computation produces `NaN` (not an error)
- If the training log has fewer than 2 iterations, return degenerate metrics (rate=0, not stationary, etc.)
- JSON serialization of the report dict uses the existing `JSON.jl` dependency

## Acceptance Criteria

- [ ] Given a `TrainingLog` with 10 iterations of decreasing gap, when `compute_gap_trajectory` is called, then a DataFrame with 10 rows and 5 columns is returned, with `gap_relative` values that are non-negative and decreasing
- [ ] Given a `TrainingLog` with 50 iterations, when `compute_convergence_rate` is called, then a Dict with all 9 expected keys is returned, and `iterations_total == 50`
- [ ] Given a `TrainingLog` where the last 20 iterations have identical bound values, when `detect_bound_stationarity` is called with default parameters, then `is_stationary == true`
- [ ] Given a `TrainingLog` with actively improving bounds, when `detect_bound_stationarity` is called, then `is_stationary == false`
- [ ] Given a `TrainingLog` with some iterations having `serious_numerical_issue == true`, when `generate_convergence_report` is called, then `had_numerical_issues == true` and the iteration numbers are listed
- [ ] Given a successful training run with `save_policy` called, when the output directory is inspected, then `convergence_analysis.csv` and `convergence_report.json` exist with correct content
- [ ] Given a `TrainingLog` that is `nothing`, when `save_policy` is called, then no convergence analysis files are written and no error occurs

## Implementation Guide

### Suggested Approach

1. **Create `src/Engines/sddp/convergence_analysis.jl`** with all four pure functions. These are standalone functions that take `TrainingLog` as input -- they do not modify any model state.

2. **Include the new file** in `src/Engines/sddp.jl` after `validate.jl`:

   ```julia
   include("sddp/convergence_analysis.jl")
   ```

3. **Add save logic in `save_policy.jl`**:
   - After existing convergence writing, add:
     ```julia
     if artifact.training_log !== nothing
         __write_convergence_analysis(artifact.training_log, writer, extension)
         __write_convergence_report(artifact.training_log)
     end
     ```
   - `__write_convergence_analysis` calls `compute_gap_trajectory` and writes the DataFrame
   - `__write_convergence_report` calls `generate_convergence_report` and writes JSON

4. **Linear regression for gap_reduction_rate**: Use a simple OLS computation (no external dependency):
   ```julia
   function _simple_linear_slope(x::Vector{Float64}, y::Vector{Float64})::Float64
       n = length(x)
       n < 2 && return 0.0
       mx, my = sum(x) / n, sum(y) / n
       num = sum((x[i] - mx) * (y[i] - my) for i in 1:n)
       den = sum((x[i] - mx)^2 for i in 1:n)
       return den > 0 ? num / den : 0.0
   end
   ```

### Key Files to Modify

- `src/Engines/sddp/convergence_analysis.jl` -- NEW file with all analysis functions
- `src/Engines/sddp.jl` -- add `include("sddp/convergence_analysis.jl")`
- `src/Engines/sddp/save_policy.jl` -- add convergence analysis writing to `Lab.save_policy`

### Patterns to Follow

- Follow the same DataFrame construction pattern used in `__get_model_convergence()` in `save_policy.jl`
- Follow the JSON writing pattern used in `src/Experiments/reproducibility.jl` for writing `convergence_report.json`
- The 10-metric statistical summary pattern in `src/Experiments/comparison.jl` (lines around 234) is a good model for the `compute_convergence_rate` return Dict

### Pitfalls to Avoid

- Do NOT import or depend on the Experiments module -- convergence analysis is an Engine-level concern, not an Experiment-level concern
- Do NOT modify `__get_model_convergence()` -- it serves a different purpose (backward-compatible convergence CSV)
- When computing `log(gap_relative)`, filter out iterations where `gap_relative <= 0` to avoid `DomainError`
- The gap trajectory should use the absolute value of the bound for the denominator to handle both minimization and maximization
- JSON serialization of `Symbol` values requires conversion to `String` first
- Keep all functions pure (no side effects) -- file I/O happens only in the `save_policy` integration

## Testing Requirements

### Unit Tests

Create `test/test-convergence-analysis.jl`:

- Construct mock `TrainingLog` objects (no actual SDDP training needed) and test each function:
  - `compute_gap_trajectory` with known values, verify gap computation
  - `compute_convergence_rate` with monotonically decreasing gaps
  - `detect_bound_stationarity` with stationary and non-stationary logs
  - `generate_convergence_report` aggregation
- Edge cases:
  - Empty iterations vector
  - Single iteration
  - All gaps are zero (converged from start)
  - Bound is zero (division handling)
  - All iterations have numerical issues

### Integration Tests

In the same file, using `example/1dtoy` with `max_iterations: 5`:

- Run build + train, verify `artifact.training_log` is not nothing
- Call `compute_gap_trajectory(artifact.training_log)` and verify DataFrame shape
- Call `generate_convergence_report(artifact.training_log)` and verify report structure
- Call `save_policy` to a temp directory, verify `convergence_analysis.csv` and `convergence_report.json` exist and are valid

Use `mktempdir() do tmpdir ... end` for output tests.
Use `TEST_FILTER="test-convergence-analysis"` with 180000ms timeout.

### E2E Tests

Not required for this ticket.

## Dependencies

- **Blocked By**: ticket-038
- **Blocks**: ticket-040

## Effort Estimate

**Points**: 3
**Confidence**: High
