# ticket-025b Fix test-main Hanging / Investigate Test Suite Reliability

## Priority: EMERGENCY

This ticket has maximum priority and blocks all further plan execution. The `test-main` filter hangs intermittently (observed: 1h+ hang during guardian verification of ticket-025). This wastes agent time and blocks CI/CD.

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `bug-investigator`

## Context

### Problem

Running `TEST_FILTER="test-main" julia --project -e 'using Pkg; Pkg.test()'` hangs intermittently. The test-main file (`test/test-main.jl`) runs an end-to-end pipeline (read_study -> build -> train -> simulate -> save) on the 1dtoy example case. When it hangs, it consumes the full session timeout with no output, blocking all further work.

### Known History

- Adding tests to existing `test-engines.jl` caused SIGABRT in earlier epics (unclear root cause) -- creating separate test files worked around it
- GLPK is NOT thread-safe -- SDDP.Threaded() with GLPK causes SIGABRT
- The test suite has ~940 tests across many files; filtered runs (unit tests) complete in seconds
- The full suite takes ~4 min normally, but `test-main` specifically can hang indefinitely

### Impact

- Guardian agents cannot verify end-to-end regressions safely
- Plan execution is blocked whenever a hang occurs
- No timeout protection in subagent test dispatch currently

## Specification

### Requirements

1. **Investigate root cause**: Profile/trace what `test-main` does and identify where the hang occurs (solver? SDDP.train? file I/O? signal handling?)
2. **Add timeout protection to test-main**: Wrap the e2e test in a timeout mechanism so it fails fast instead of hanging
3. **Add a lightweight regression test alternative**: Create a fast sanity check that validates core pipeline integration without running the full SDDP training (e.g., build-only test, or train with iteration_limit=1)
4. **Document test reliability guidelines**: Update the master plan's Test Execution Protocol with explicit rules about timeouts

### Outputs/Behavior

- `test-main` either completes within 120 seconds or fails with a clear timeout error
- A new lightweight integration test exists that validates the pipeline without risk of hanging
- All agents dispatched for testing know to use timeouts

## Acceptance Criteria

- [ ] Root cause of the hang is identified (or narrowed down to a specific component)
- [ ] `test-main` has timeout protection (fails fast after 120s instead of hanging forever)
- [ ] A lightweight pipeline test exists as an alternative for quick regression checks
- [ ] Running `TEST_FILTER="test-main"` 3 times in a row completes without hanging
- [ ] All existing tests continue to pass

## Investigation Guide

### Step 1: Reproduce

```bash
# Run with timeout to see if it hangs
timeout 120 julia --project -e 'using Pkg; Pkg.test()' 2>&1
```

### Step 2: Check what test-main does

Read `test/test-main.jl` and trace the full pipeline:

- Does it call `SDDP.train`? With what iteration limit?
- Does it write files? Where?
- Does it use any threading or distributed features?
- Does it have cleanup (rm temp files)?

### Step 3: Potential causes

- **SDDP.train convergence**: If no iteration_limit, train runs until convergence which could take very long
- **Solver hanging**: GLPK sometimes hangs on certain LP configurations
- **File I/O contention**: Writing results to disk during test
- **Signal handling**: Julia's test infrastructure can mask SIGINT
- **GC pressure**: Large model objects not freed between tests

### Step 4: Fix approaches

- Add `@timeout` or `Base.Timer` wrapper around the e2e test
- Set explicit `iteration_limit` in the test configuration
- Add `stopping_rules` with a low iteration bound in test config

## Dependencies

- **Blocked By**: none (emergency, highest priority)
- **Blocks**: all remaining tickets (026, 027, and beyond) — guardian verification depends on reliable test execution

## Effort Estimate

**Points**: 2
**Confidence**: Medium
