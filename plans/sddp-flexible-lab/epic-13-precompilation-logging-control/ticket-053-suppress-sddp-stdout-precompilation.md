# ticket-053 Suppress SDDP.jl Stdout During Precompilation

## Context

### Background

SDDP.jl's `train()` function writes training progress to stdout at `print_level >= 1` (the default). During precompilation, any stdout output is undesirable -- it confuses users and pollutes package precompilation logs. Ticket-052 already sets `print_level=0` in the workload's `SDDP.train` call, but SDDP.jl may also emit output from internal routines (solver setup, bridge selection warnings). Additionally, HiGHS itself prints banner messages on first use. This ticket ensures ALL output is suppressed by validating and hardening the `redirect_stdout(devnull)` / `redirect_stderr(devnull)` wrapping, and by verifying that HiGHS's output is silenced.

### Relation to Epic

This is the final ticket in Epic 13. It hardens the output suppression that ticket-052 initiates, ensuring a completely silent precompilation experience.

### Current State

- Ticket-052 wraps the workload in `redirect_stdout(devnull) do; redirect_stderr(devnull) do; ... end; end` and sets `print_level=0` on `SDDP.train`
- HiGHS.Optimizer may emit a banner message ("Running HiGHS ...") on first instantiation unless `MOI.set(optimizer, MOI.Silent(), true)` is called
- JuMP.jl may emit bridge-related `@info` messages during model construction
- The `TrainingLogConfig` struct in `src/Engines/Engines.jl` has a `print_level::Int` field that is passed to `SDDP.train` kwargs in `src/Engines/sddp/train.jl`

## Specification

### Requirements

1. Ensure the precompile workload in `src/precompile_workload.jl` silences HiGHS by calling `JuMP.set_silent(model)` or `MOI.set(optimizer, MOI.Silent(), true)` on the SDDP.PolicyGraph's subproblem models
2. Verify that `redirect_stdout(devnull)` and `redirect_stderr(devnull)` are correctly nested in the workload (from ticket-052) and cover the entire workload including HiGHS initialization
3. Add a `@test_nowarn` or equivalent check in the test suite that verifies precompilation produces no output
4. Ensure that the `Logging` module's output is also suppressed during precompilation by wrapping the workload in `Logging.with_logger(Logging.NullLogger()) do ... end` to catch any `@info` / `@warn` messages from JuMP or SDDP.jl internals

### Inputs/Props

- `src/precompile_workload.jl`: the workload file from ticket-052
- SDDP.jl's `train` function signature and `print_level` kwarg
- HiGHS optimizer output behavior

### Outputs/Behavior

- During precompilation (`Pkg.precompile()` or first `using SDDPlab`), zero lines appear on stdout or stderr from the workload
- No `@info`, `@warn`, or solver banner messages leak through
- The workload still executes successfully (verified by the `@debug` fallback not triggering)

### Error Handling

- The existing `try...catch` from ticket-052 handles all failures
- No additional error handling needed

## Acceptance Criteria

- [ ] Given `src/precompile_workload.jl`, when inspected, then the workload is wrapped in `Logging.with_logger(Logging.NullLogger()) do ... end` inside the existing redirect blocks
- [ ] Given `src/precompile_workload.jl`, when inspected, then `JuMP.set_silent` or `MOI.set(optimizer, MOI.Silent(), true)` is called for the SDDP.PolicyGraph optimizer within the subproblem builder callback
- [ ] Given a fresh Julia session with the precompile cache deleted, when `using SDDPlab` is run with stdout and stderr captured to a string, then the captured string contains no lines from HiGHS, SDDP, or JuMP (only Julia's own "Precompiling SDDPlab..." message is acceptable)
- [ ] Given the test file `test/test-precompile.jl`, when run via `TEST_FILTER="test-precompile"`, then it verifies that importing SDDPlab in a subprocess produces no unexpected output

## Implementation Guide

### Suggested Approach

1. Edit `/home/rogerio/git/sddp-lab/src/precompile_workload.jl` to add the NullLogger wrapping and HiGHS silencing. The final structure should be:

```julia
let
    try
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                Logging.with_logger(Logging.NullLogger()) do
                    import HiGHS

                    graph = SDDP.LinearGraph(2)
                    model = SDDP.PolicyGraph(
                        graph;
                        sense = :Min,
                        lower_bound = 0.0,
                        optimizer = () -> begin
                            opt = HiGHS.Optimizer()
                            MOI.set(opt, MOI.Silent(), true)
                            return opt
                        end,
                    ) do sp, node
                        # ... (same as ticket-052)
                    end

                    SDDP.train(
                        model;
                        iteration_limit = 3,
                        risk_measure = SDDP.Expectation(),
                        print_level = 0,
                        log_every_iteration = false,
                    )
                end
            end
        end
    catch e
        @debug "SDDPlab precompile workload failed (non-fatal): $e"
    end
end
```

Key changes from ticket-052's version:

- Added `Logging.with_logger(Logging.NullLogger())` wrapper
- Changed optimizer to a factory function that sets `MOI.Silent()` on HiGHS
- Added `import MathOptInterface as MOI` usage (already available in module scope from `SDDPlab.jl`)

2. Ensure `using Logging` is available in `SDDPlab.jl`. Check if `Logging` is already imported (it is listed in `Project.toml` deps). If not, add `using Logging` before the `@compile_workload` block.

3. Create a test file `/home/rogerio/git/sddp-lab/test/test-precompile.jl` that:
   - Spawns a subprocess: `julia --project -e 'using SDDPlab'` with stdout/stderr captured
   - Asserts the captured output does not contain "HiGHS", "Running", "Iteration", or solver banner strings
   - Note: this test may take 60+ seconds on first run (precompilation) so use a generous timeout

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/src/precompile_workload.jl`

### Key Files to Create

- `/home/rogerio/git/sddp-lab/test/test-precompile.jl`

### Patterns to Follow

- Use the optimizer factory pattern `() -> begin opt = HiGHS.Optimizer(); MOI.set(opt, MOI.Silent(), true); opt end` which matches how `create_optimizer` works in `src/Engines/sddp/solver.jl`
- Use `Logging.NullLogger()` pattern from Julia stdlib for suppressing log messages during code that emits `@info`/`@warn`

### Pitfalls to Avoid

- Do NOT remove the `redirect_stdout`/`redirect_stderr` wrappers thinking NullLogger is sufficient -- NullLogger only suppresses Julia's Logging-based output, not raw `println` or C-level stdout from HiGHS
- Do NOT set `MOI.Silent()` on the PolicyGraph itself -- it must be set on each subproblem optimizer instance via the factory function
- Do NOT use `Suppressor.jl` in the precompile workload -- it is a test dependency only and not available during precompilation
- The test for output suppression must use a subprocess (not in-process) because precompilation only runs on first import

## Testing Requirements

### Unit Tests

- Not applicable (output suppression is verified via integration test)

### Integration Tests

- `test/test-precompile.jl`: subprocess test that verifies `using SDDPlab` produces no HiGHS/SDDP output strings

### E2E Tests

- Not applicable

## Dependencies

- **Blocked By**: ticket-052-implement-smart-precompile-workload.md
- **Blocks**: None within Epic 13. Epic 14 tickets depend on Epic 13 completion.

## Effort Estimate

**Points**: 2
**Confidence**: High
