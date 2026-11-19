# Epic 13: Precompilation & Logging Control

## Goal

Integrate PrecompileTools.jl into SDDPlab to eliminate Time-To-First-Execution (TTFX) overhead. The precompile workload must exercise the full SDDP training loop on a tiny synthetic problem, covering the most common code paths (HiGHS solver, Expectation risk, IterationLimit stopping, Serial parallelism, DefaultForwardPass, SingleCut, NoScaling, Naive stochastic process). SDDP.jl's stdout logging must be suppressed during precompilation via `print_level=0` and stdout redirection to `devnull`.

## Scope

- Add PrecompileTools.jl as a dependency
- Create a minimal precompile workload that exercises the hot SDDP training path
- Suppress all stdout/stderr output during precompilation
- Validate TTFX reduction with before/after benchmarks
- Ensure the precompile workload does not increase package load time excessively

## Non-Goals

- Custom sysimage build scripts (deferred to Epic 14)
- Exercising every configuration permutation
- Supporting GLPK in the precompile workload (HiGHS only for precompilation)
- MPI/distributed precompilation paths

## Tickets

| Ticket     | Title                                                        | Agent               | Points |
| ---------- | ------------------------------------------------------------ | ------------------- | ------ |
| ticket-051 | Add PrecompileTools dependency and compile_workload scaffold | hpc-julia-developer | 2      |
| ticket-052 | Implement smart precompile workload for SDDP training loop   | sddp-specialist     | 3      |
| ticket-053 | Suppress SDDP.jl stdout during precompilation                | hpc-julia-developer | 2      |

## Dependencies

- Depends on: All epics 01-12 (completed)
- Blocks: Epic 14 (the precompile workload feeds into create_app)
