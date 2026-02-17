# ticket-033 Add Convergence Analysis Tools

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: None

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create tools for analyzing convergence behavior after training, including bound gap analysis, convergence rate estimation, cut quality metrics, and policy stability assessment. These tools help users understand whether the algorithm has converged satisfactorily and diagnose slow convergence.

## Anticipated Scope

- **Files likely to be modified**: new file `src/Engines/sddp/convergence_analysis.jl`, `src/Engines/sddp/save_policy.jl` (additional metrics)
- **Key decisions needed**: What metrics to compute (gap trajectory, convergence rate, cut density). Whether to produce structured data or visualizations.
- **Open questions**:
  - Should convergence analysis include statistical tests for bound stationarity?
  - How to assess policy stability across different random seeds?
  - Should this integrate with the experiment comparison framework from Epic 07?

## Dependencies

- **Blocked By**: ticket-032
- **Blocks**: ticket-034

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
