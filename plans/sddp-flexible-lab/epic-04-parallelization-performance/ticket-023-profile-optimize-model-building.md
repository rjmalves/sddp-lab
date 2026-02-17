# ticket-019 Profile and Optimize Model Building Hot Paths

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Profile the model building pipeline (SAA generation, subproblem construction, system element addition) to identify performance bottlenecks, then optimize the top bottlenecks. Target at least 2x speedup for model building on the larger example cases.

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (hot paths), `src/StochasticProcess/*.jl` (SAA generation), `src/System/*.jl` (element addition)
- **Key decisions needed**: Which profiling tool to use (Julia's built-in Profile, BenchmarkTools, or Chairmarks). What the performance baseline is.
- **Open questions**:
  - What is the current model build time for each example case?
  - Are allocations dominated by SAA generation or JuMP model construction?
  - Can SAA generation be parallelized independently of SDDP.jl?

## Dependencies

- **Blocked By**: ticket-018
- **Blocks**: ticket-020

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
