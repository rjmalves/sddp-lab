# ticket-025 Add Multivariate Stochastic Process Support

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify sampling performance and allocation-free hot paths)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Extend the stochastic process framework to properly support multivariate processes where the correlation structure between different hydro inflows (and potentially other uncertain variables) is explicitly modeled. While the current Naive process uses Copulas for correlation, the AutoRegressive process has limited multivariate support. This ticket generalizes the framework.

## Anticipated Scope

- **Files likely to be modified**: `src/StochasticProcess/StochasticProcess.jl`, `src/StochasticProcess/autoregressive.jl`, new file `src/StochasticProcess/multivariate.jl`
- **Key decisions needed**: Whether to use VAR (Vector AutoRegressive) models or keep the existing AR structure with copula-based dependence. How to specify cross-correlation matrices in JSONC.
- **Open questions**:
  - Should the multivariate process handle both inflow and renewable availability?
  - How does the copula-based approach in Naive scale to high dimensions?
  - What estimation methods should be supported for the multivariate parameters?

## Dependencies

- **Blocked By**: ticket-024 (Epic 05 complete)
- **Blocks**: ticket-026

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
