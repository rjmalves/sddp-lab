# ticket-018 Implement Thread-Safe SAA Generation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SAA reproducibility with parallel RNG)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Make the Sample Average Approximation (SAA) generation process thread-safe by using per-thread random number generators. Currently, `generate_saa` in the Engines module uses the global RNG via `Random.seed!`, which is not safe for concurrent access from multiple threads.

## Anticipated Scope

- **Files likely to be modified**: `src/Scenarios/Scenarios.jl` (set_seed!), `src/StochasticProcess/naive.jl`, `src/StochasticProcess/autoregressive.jl`, `src/Engines/sddp/build.jl` (SAA generation)
- **Key decisions needed**: Whether to use `TaskLocalRNG` or explicit `MersenneTwister` per thread. How to maintain reproducibility with parallel RNG.
- **Open questions**:
  - Should seeds be derived deterministically per thread from the master seed?
  - Does SDDP.jl's internal scenario sampling also need thread-safe RNG?

## Dependencies

- **Blocked By**: ticket-017
- **Blocks**: ticket-019

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
