# ticket-015 Integrate Numerical Stability Diagnostics

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: None

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Integrate SDDP.jl's `numerical_stability_report()` function into the SDDPlab pipeline to provide automatic coefficient analysis after model building. Add a diagnostic step that reports the range of variable bounds, constraint coefficients, and objective coefficients, and flags potential numerical issues before training begins.

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (add post-build diagnostic step), `src/Engines/Engines.jl` (diagnostic configuration), `src/Lab/tasks.jl` (optional diagnostic interface)
- **Key decisions needed**: Whether diagnostics run automatically or are opt-in. How diagnostic results are reported (log output, structured data, or both).
- **Open questions**:
  - Should `numerical_stability_report()` be called on every node or a representative subset?
  - Should diagnostics block training if severe issues are detected, or just warn?

## Dependencies

- **Blocked By**: ticket-014
- **Blocks**: ticket-016

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
