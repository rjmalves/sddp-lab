# ticket-019 Integrate Numerical Stability Diagnostics

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: None

## Context

### Background

SDDP.jl provides a built-in `SDDP.numerical_stability_report(model)` function that analyzes the coefficient matrix of each subproblem and reports the range of variable bounds, constraint coefficients, objective coefficients, and RHS values. This is invaluable for diagnosing numerical issues before starting a potentially long training run. Currently, SDDPlab does not expose this diagnostic capability -- users must manually call it on the SDDP policy graph object.

This ticket integrates the numerical stability report into the SDDPlab pipeline as an optional post-build diagnostic step, configurable via JSONC. It runs after model construction and before training, logging the results and optionally halting if severe numerical issues are detected.

### Relation to Epic

This is the third ticket in Epic 03. It provides observability into the LP conditioning of the built model. Combined with the units registry (ticket-017) and scaling (ticket-018), it gives users a complete workflow: build the model, check conditioning, optionally enable scaling, and verify improvement.

### Current State

- `src/Engines/sddp/build.jl` has `Lab.build(::SDDPEngine, files, optimizer)::SDDPModel` which builds the `SDDP.PolicyGraph` and returns it wrapped in `SDDPModel`.
- `src/study.jl` calls `Lab.build` then `Lab.train` in sequence with no diagnostic step between them.
- SDDP.jl's `numerical_stability_report(model::SDDP.PolicyGraph; by_node=false)` function exists and prints to stdout by default, but can accept an `io` parameter.
- The `SDDPModel` struct holds only `policy_graph::SDDP.PolicyGraph`.
- There is no diagnostics configuration in the engine JSONC config.

## Specification

### Requirements

1. **Add `DiagnosticsConfig` struct** to `src/Engines/Engines.jl`:
   - `run_numerical_report::Bool` -- whether to run the stability report after build (default: `false`).
   - `warn_threshold::Float64` -- coefficient range ratio above which a warning is logged (default: `1e6`). The range ratio is `max_abs_coefficient / min_abs_nonzero_coefficient`.
   - `halt_threshold::Float64` -- coefficient range ratio above which training is halted with an error (default: `1e10`). Set to `Inf` to never halt.

2. **Add JSONC configuration** for diagnostics:
   - Optional `"diagnostics"` key in the engine params, at the same level as `"policy"` and `"simulation"`.
   - JSONC example:
     ```jsonc
     "diagnostics": {
         "run_numerical_report": true,
         "warn_threshold": 1e6,
         "halt_threshold": 1e10
     }
     ```
   - When the `"diagnostics"` key is absent, default to `DiagnosticsConfig(false, 1e6, 1e10)` (backward compatible, diagnostics off).

3. **Create `src/Engines/sddp/diagnostics.jl`** with:
   - A function `run_diagnostics(model::SDDP.PolicyGraph, config::DiagnosticsConfig)::Bool` that:
     a. Calls `SDDP.numerical_stability_report(model)` capturing output to a string via `IOBuffer`.
     b. Parses the output to extract the coefficient range (min and max absolute values).
     c. Computes the range ratio.
     d. Logs the full report at `@info` level.
     e. If ratio exceeds `warn_threshold`, logs a `@warn` with the ratio and recommendation to enable scaling.
     f. If ratio exceeds `halt_threshold`, logs an `@error` and returns `false`.
     g. Otherwise returns `true`.

4. **Add `diagnostics` field to `SDDPEngine`**:
   - `SDDPEngine` struct gets a `diagnostics::DiagnosticsConfig` field.
   - Constructor defaults to `DiagnosticsConfig(false, 1e6, 1e10)` when not present in JSONC.

5. **Wire diagnostics into the pipeline**:
   - In `src/study.jl`, after `build` and before `train`, check if `diagnostics.run_numerical_report` is true. If so, call `run_diagnostics`. If it returns `false` (halt), throw an error.
   - Alternatively, add a `diagnose` function at the study level that can be called explicitly.

### Inputs/Props

- `DiagnosticsConfig`: parsed from JSONC engine config.
- `SDDP.PolicyGraph`: the built model to diagnose.

### Outputs/Behavior

- When `run_numerical_report` is `false`: no diagnostic output, no performance impact.
- When `run_numerical_report` is `true`: the stability report is logged, and thresholds are checked.
- The stability report output goes to Julia's `@info` logger, not to stdout.

### Error Handling

- If `SDDP.numerical_stability_report` throws (e.g., empty model), catch and log a warning but do not halt.
- Follow the established `CompositeException` pattern for JSONC parsing validation.
- If `halt_threshold < warn_threshold`, push an `AssertionError` during validation.

## Acceptance Criteria

- [ ] Given `DiagnosticsConfig(false, 1e6, 1e10)`, when the pipeline runs, then no diagnostics output is produced (backward compatible)
- [ ] Given `DiagnosticsConfig(true, 1e6, 1e10)`, when the pipeline runs on the 1dtoy example, then the stability report is logged at `@info` level
- [ ] Given a model with coefficient range ratio of 1e8, when `run_diagnostics` is called with `warn_threshold = 1e6`, then a `@warn` is logged
- [ ] Given a model with coefficient range ratio of 1e12, when `run_diagnostics` is called with `halt_threshold = 1e10`, then the function returns `false`
- [ ] Given JSONC without a `"diagnostics"` key, when the engine is parsed, then `DiagnosticsConfig(false, 1e6, 1e10)` is used
- [ ] Given `{"run_numerical_report": true, "warn_threshold": 1e6, "halt_threshold": 1e10}`, when parsed, then a valid `DiagnosticsConfig` is returned
- [ ] Given `halt_threshold < warn_threshold` in JSONC, when parsed, then an `AssertionError` is pushed

## Implementation Guide

### Suggested Approach

1. Add `DiagnosticsConfig` struct to `src/Engines/Engines.jl`:

   ```julia
   struct DiagnosticsConfig
       run_numerical_report::Bool
       warn_threshold::Float64
       halt_threshold::Float64
   end
   ```

2. Add `diagnostics` field to `SDDPEngine`:

   ```julia
   struct SDDPEngine <: Engine
       policy::SDDPPolicyTaskDefinition
       simulation::SDDPSimulationTaskDefinition
       diagnostics::DiagnosticsConfig
   end
   ```

3. Add constructor and validators in `src/Engines/sddp/input.jl` and `input-validators.jl`:

   ```julia
   const DIAGNOSTICS_SCHEMA = [
       FieldRule("run_numerical_report", Bool),
       FieldRule("warn_threshold", Real; constraints = [positive()]),
       FieldRule("halt_threshold", Real; constraints = [positive()]),
   ]

   function DiagnosticsConfig(d::Dict{String,Any}, e::CompositeException)
       valid = validate_schema!(d, DIAGNOSTICS_SCHEMA, e)
       valid_cross = valid && d["halt_threshold"] >= d["warn_threshold"]
       valid_cross || push!(e, AssertionError("halt_threshold must be >= warn_threshold"))
       return valid_cross ? DiagnosticsConfig(
           d["run_numerical_report"], d["warn_threshold"], d["halt_threshold"]
       ) : nothing
   end
   ```

4. Handle optional key in `SDDPEngine` constructor:

   ```julia
   function __build_diagnostics!(d::Dict{String,Any}, e::CompositeException)::Bool
       if !haskey(d, "diagnostics")
           d["diagnostics"] = DiagnosticsConfig(false, 1e6, 1e10)
           return true
       end
       # validate and construct from dict...
   end
   ```

5. Create `src/Engines/sddp/diagnostics.jl`:

   ```julia
   function run_diagnostics(model::SDDP.PolicyGraph, config::DiagnosticsConfig)::Bool
       if !config.run_numerical_report
           return true
       end

       io = IOBuffer()
       try
           SDDP.numerical_stability_report(model; io = io)
       catch ex
           @warn "numerical_stability_report failed: $ex"
           return true
       end

       report = String(take!(io))
       @info "Numerical Stability Report:\n$report"

       # Parse coefficient ranges from report text
       # ... extract min/max, compute ratio
       # Compare against thresholds
       return true  # or false if halt_threshold exceeded
   end
   ```

6. Wire into `src/study.jl` by adding a `diagnose` function or integrating into the build step. The cleanest approach is to add a public `diagnose(study, model)` function and call it in the pipeline tests.

### Key Files to Modify

- `src/Engines/Engines.jl` -- add `DiagnosticsConfig`, update `SDDPEngine`
- `src/Engines/sddp/input.jl` -- add `DiagnosticsConfig` constructor, update `SDDPEngine` constructor
- `src/Engines/sddp/input-validators.jl` -- add `DIAGNOSTICS_SCHEMA` and validators
- `src/Engines/sddp/diagnostics.jl` -- **new file**, diagnostic runner
- `src/Engines/sddp.jl` -- include `diagnostics.jl`
- `src/study.jl` -- add `diagnose` function or integrate into pipeline

### Patterns to Follow

- Optional field with `haskey` check and default value (same as `duality_handler`, `forward_pass`, `sampling_scheme` in `SDDPPolicyTaskDefinition`).
- Schema validation with `FieldRule` and `validate_schema!` for the diagnostics config fields.
- Cross-field validation (`halt >= warn`) after schema passes (same as `Convergence` min/max check).

### Pitfalls to Avoid

- `SDDP.numerical_stability_report` may not accept an `io` keyword in all SDDP.jl versions. Check the SDDP.jl source first. If `io` is not supported, capture stdout using `redirect_stdout`.
- Parsing the text output of `numerical_stability_report` is fragile. Consider just logging the report and computing the range ratio from JuMP directly (iterate `JuMP.all_constraints` on a representative subproblem).
- The diagnostics should NOT modify the model in any way.
- Adding `diagnostics` to `SDDPEngine` changes its constructor signature. All existing tests that construct `SDDPEngine` directly (in `test/test-main.jl`) will need the third argument. Provide a convenience constructor or use a default.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-diagnostics.jl`:

- Test `DiagnosticsConfig` JSONC parsing with valid config.
- Test `DiagnosticsConfig` JSONC parsing with missing key (default values).
- Test `DiagnosticsConfig` validation: `halt_threshold < warn_threshold` rejected.
- Test `SDDPEngine` construction with and without `diagnostics` key (backward compat).

### Integration Tests

- Run the 1dtoy example with `run_numerical_report = true` and verify diagnostics output is produced without errors.
- Run the 1dtoy example with `run_numerical_report = false` and verify no diagnostics output.

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-016 (Epic 02 complete)
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Medium
