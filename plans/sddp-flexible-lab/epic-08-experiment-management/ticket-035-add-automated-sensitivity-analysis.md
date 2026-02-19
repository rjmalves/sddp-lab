# ticket-035 Add Automated Sensitivity Analysis

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify sensitivity parameters are SDDP-meaningful)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Build a sensitivity analysis framework that automatically varies one or more algorithm parameters across a specified range, runs the pipeline for each combination, and collects metrics to identify how sensitive results are to each parameter.

## Anticipated Scope

- **Files likely to be modified**: `src/Experiments/Experiments.jl`, new file `src/Experiments/sensitivity.jl`
- **Key decisions needed**: Whether to support one-at-a-time (OAT) sensitivity, full factorial, or Latin hypercube sampling. How parameter ranges are specified.
- **Open questions**:
  - What metrics are tracked (convergence speed, final bound, simulation cost)?
  - Should the framework support parallelizing sensitivity runs?
  - How are parameter combinations specified in the config?

## Dependencies

- **Blocked By**: ticket-034
- **Blocks**: ticket-036

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
