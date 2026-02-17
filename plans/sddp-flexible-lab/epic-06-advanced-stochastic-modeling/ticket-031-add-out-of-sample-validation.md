# ticket-027 Add Out-of-Sample Validation Framework

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify statistical computation performance)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create a framework for validating policy quality using out-of-sample scenarios. This includes generating independent scenario sets, simulating the trained policy on those scenarios, and computing statistical metrics (mean cost, confidence intervals, worst-case cost) to assess policy robustness.

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/simulate.jl`, new file `src/Engines/sddp/validation.jl`, `src/Lab/tasks.jl` (validation task interface)
- **Key decisions needed**: Whether out-of-sample validation is a separate task type or an extension of simulation. How to generate independent scenario sets (different seed, different distribution parameters).
- **Open questions**:
  - Should the out-of-sample scenarios be generated from the same stochastic model with a different seed, or from a completely separate model?
  - What statistical metrics should be computed and reported?
  - Should this integrate with SDDP.jl's `OutOfSampleMonteCarlo` sampling scheme?

## Dependencies

- **Blocked By**: ticket-026
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
