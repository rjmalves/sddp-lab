# ticket-014 Implement Automatic LP Coefficient Scaling

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify JuMP model transformation performance)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Implement automatic scaling of LP coefficients in the SDDP subproblem formulation to improve numerical stability. This involves analyzing the coefficient matrix after model construction and applying variable/constraint scaling to bring coefficients into a numerically well-conditioned range (typically [1e-3, 1e3]).

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (post-build scaling step), new file `src/Engines/sddp/scaling.jl`, `src/Engines/Engines.jl` (scaling configuration types)
- **Key decisions needed**: Whether scaling is applied at model build time or as a preprocessing step before solve. Whether to use geometric mean scaling, equilibrium scaling, or user-specified scaling factors. How scaling interacts with SDDP.jl's cut generation.
- **Open questions**:
  - Does SDDP.jl support custom variable/constraint scaling, or must scaling be applied manually via JuMP transforms?
  - Should scaling be automatic (computed from coefficients) or configurable via JSONC?
  - How does scaling interact with state variables (SDDP.State)?

## Dependencies

- **Blocked By**: ticket-013
- **Blocks**: ticket-015

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
