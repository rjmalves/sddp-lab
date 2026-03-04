# ticket-052 Implement Smart Precompile Workload for SDDP Training Loop

## Context

### Background

After ticket-051 adds the PrecompileTools scaffold, this ticket populates the `@compile_workload` block with a representative SDDP training workload. The workload must exercise the most common code paths to maximize native code caching: case data loading/validation, JuMP model construction with HiGHS (via `Model(HiGHS.Optimizer)` to trigger MOI bridge compilation), SDDP.PolicyGraph construction, forward pass, backward pass, and convergence check. The workload uses the "smart coverage" strategy: exercise the most common configuration (HiGHS + Expectation + IterationLimit + Serial + DefaultForwardPass + SingleCut + NoScaling + Naive stochastic process) rather than trying every permutation.

### Relation to Epic

This is the core ticket in Epic 13. It implements the actual precompile workload that eliminates TTFX. Ticket-051 provides the scaffold; ticket-053 handles output suppression.

### Current State

- `src/precompile_workload.jl` exists but contains only a placeholder comment (from ticket-051)
- The `@compile_workload` block in `SDDPlab.jl` includes this file
- The full SDDP pipeline is: `read_study(path)` -> `Study` -> `build(study)` -> `SDDPModel` -> `train(study, model)` -> `PolicyTaskArtifact`
- `read_study` expects a directory with `main.jsonc` and data files
- The training pipeline in `src/Engines/sddp/train.jl` calls `SDDP.train(model.policy_graph; kwargs...)` with kwargs for risk_measure, stopping_rules, parallel_scheme, sampling_scheme, cut_type, duality_handler, forward_pass, print_level, log_frequency, log_every_iteration
- JuMP model construction happens in `src/Engines/sddp/build.jl` via `add_system_elements!` methods and `__generate_subproblem_builder`
- HiGHS solver creation uses dynamic `Base.require(Main, :HiGHS)` in `src/Engines/sddp/solver.jl`

## Specification

### Requirements

1. Implement the precompile workload in `/home/rogerio/git/sddp-lab/src/precompile_workload.jl` that runs a complete but tiny SDDP training loop
2. The workload must construct a synthetic problem programmatically (NOT by reading files from disk) to avoid filesystem dependencies during precompilation
3. The synthetic problem must be minimal: 2 stages, 1 bus, 1 thermal, 1 hydro, 3 scenarios, no lines, no non-controllables, no contracts, no pumping stations, Naive stochastic process
4. The workload must exercise these exact code paths:
   - `SDDP.PolicyGraph` construction with `HiGHS.Optimizer`
   - JuMP variable creation (`@variable` with bounds, `SDDP.State` variables)
   - JuMP constraint creation (`@constraint` with linear expressions)
   - `SDDP.@stageobjective` with linear cost
   - `SDDP.parameterize` with noise realizations
   - `SDDP.train` with: `iteration_limit=3`, `SDDP.Expectation()` risk, `SDDP.Serial()` parallel, `print_level=0`
5. The workload must complete in under 30 seconds during precompilation
6. All output (stdout and stderr) from the workload must be suppressed -- achieved by wrapping in `redirect_stdout(devnull) do; redirect_stderr(devnull) do; ... end; end` (ticket-053 may refine this, but the workload itself must set `print_level=0`)
7. The workload must NOT call `read_study` or access any files -- it constructs SDDP.PolicyGraph directly using SDDP.jl's API to avoid coupling with the SDDPlab input format during precompilation

### Inputs/Props

- No external inputs. The synthetic problem is self-contained in code.

### Outputs/Behavior

- During `Pkg.precompile()` or first `using SDDPlab`, the workload executes silently
- After precompilation, subsequent `using SDDPlab` sessions benefit from cached native code
- The workload produces no files, no output, and no side effects

### Error Handling

- The entire workload must be wrapped in a `try...catch` that silently swallows all exceptions. A failed precompile workload must NOT prevent the package from loading.
- Log a `@debug` message if the workload fails (visible only with JULIA_DEBUG=SDDPlab)

## Acceptance Criteria

- [ ] Given `/home/rogerio/git/sddp-lab/src/precompile_workload.jl`, when inspected, then it constructs a 2-stage SDDP.PolicyGraph with HiGHS.Optimizer, defines JuMP variables with bounds, defines SDDP.State variables, adds linear constraints, sets SDDP.@stageobjective, calls SDDP.parameterize, and calls SDDP.train with iteration_limit=3
- [ ] Given a fresh Julia session, when `@time using SDDPlab` is run (triggering precompilation), then the workload completes within 120 seconds and produces no stdout/stderr output
- [ ] Given `src/precompile_workload.jl`, when inspected, then it does NOT call `read_study`, `open`, `read`, or any filesystem I/O function
- [ ] Given a precompiled SDDPlab, when `@time using SDDPlab` is run in a fresh session, then load time is under 15 seconds (vs. first-time precompilation which may take 60-120s)
- [ ] Given `src/precompile_workload.jl`, when inspected, then the entire workload body is wrapped in `try...catch` with a `@debug` fallback message

## Implementation Guide

### Suggested Approach

Implement `/home/rogerio/git/sddp-lab/src/precompile_workload.jl` with the following structure:

```julia
# PrecompileTools workload for SDDPlab
# Exercises the hot SDDP training path to cache native code.

let
    try
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                import HiGHS

                # Build a tiny 2-stage linear SDDP problem
                graph = SDDP.LinearGraph(2)
                model = SDDP.PolicyGraph(
                    graph;
                    sense = :Min,
                    lower_bound = 0.0,
                    optimizer = HiGHS.Optimizer,
                ) do sp, node
                    # State variable (mimics hydro storage)
                    JuMP.@variable(sp, 0 <= volume <= 100, SDDP.State, initial_value = 50)
                    # Control variables (mimics thermal gen + deficit)
                    JuMP.@variable(sp, 0 <= thermal <= 50)
                    JuMP.@variable(sp, 0 <= deficit <= 100)
                    # Random inflow
                    JuMP.@variable(sp, inflow)
                    # Hydro balance constraint
                    JuMP.@constraint(sp, volume.out == volume.in + inflow - thermal)
                    # Load balance
                    JuMP.@constraint(sp, thermal + deficit >= 30)
                    # Objective
                    SDDP.@stageobjective(sp, 10.0 * thermal + 500.0 * deficit)
                    # Parameterize with noise
                    SDDP.parameterize(sp, [10.0, 20.0, 30.0]) do omega
                        return JuMP.fix(inflow, omega)
                    end
                end

                # Train for 3 iterations (minimal, just to compile the path)
                SDDP.train(
                    model;
                    iteration_limit = 3,
                    risk_measure = SDDP.Expectation(),
                    print_level = 0,
                    log_every_iteration = false,
                )
            end
        end
    catch e
        @debug "SDDPlab precompile workload failed (non-fatal): $e"
    end
end
```

Key design decisions in the workload:

- Uses `SDDP.LinearGraph(2)` instead of the full `read_study` pipeline to avoid filesystem coupling
- Uses `HiGHS.Optimizer` directly (not via `create_optimizer`) to exercise the MOI bridge path that JuMP uses
- Includes `SDDP.State` variable to compile the state-variable codepath (forward/backward pass)
- Includes `SDDP.parameterize` to compile the noise-realization codepath
- Uses `SDDP.@stageobjective` to compile the objective construction path
- Only 3 iterations -- enough to compile the forward+backward pass code, not enough to waste time
- The `let` block scopes all variables to avoid polluting the module namespace

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/src/precompile_workload.jl` (replace placeholder with actual workload)

### Patterns to Follow

- Use `SDDP.jl`'s public API directly (not SDDPlab's wrapper functions) to minimize coupling
- Follow the same JuMP variable/constraint patterns used in `src/Engines/sddp/build.jl`: `@variable` with bounds, `SDDP.State`, `@constraint` with linear expressions
- Use `let...end` block to scope local variables (same pattern used in Julia package precompilation best practices)

### Pitfalls to Avoid

- Do NOT use `read_study` or any file I/O -- precompilation runs in a restricted environment where the working directory may not be the project root
- Do NOT exercise GLPK -- it is not a direct dependency and `Base.require(Main, :GLPK)` would fail during precompilation
- Do NOT increase iteration_limit beyond 5 -- more iterations do not compile additional code paths but linearly increase precompilation time
- Do NOT use `Model(HiGHS.Optimizer)` (JuMP's `Model`) -- use `SDDP.PolicyGraph` directly since that is the actual hot path
- Do NOT call `simulate` -- it uses the same JuMP code paths as `train` and would double precompilation time for minimal additional caching
- Do NOT import HiGHS at module level (`using HiGHS`) -- use `import HiGHS` inside the workload to keep it contained. HiGHS is a `[deps]` dependency (from ticket-051) so `import` works during precompilation.

## Testing Requirements

### Unit Tests

- No dedicated unit tests for the precompile workload (it runs during precompilation, not at test time)

### Integration Tests

- Verify `using SDDPlab` succeeds in a fresh Julia session after deleting the precompile cache: `rm -rf ~/.julia/compiled/v1.*/SDDPlab/` then `julia --project -e 'using SDDPlab'`
- Verify the existing test suite still passes: `TEST_FILTER="test-engines" julia --project -e 'using Pkg; Pkg.test()'`

### E2E Tests

- Not applicable (precompilation is a compile-time concern)

## Dependencies

- **Blocked By**: ticket-051-add-precompiletools-dependency-scaffold.md
- **Blocks**: ticket-053-suppress-sddp-stdout-precompilation.md, ticket-054-add-julia-main-entry-point.md (Epic 14)

## Effort Estimate

**Points**: 3
**Confidence**: Medium (SDDP.jl's internal compilation patterns may require iteration to get the workload coverage right)
