# Epic 03: Units and LP Conditioning

## Goal

Add explicit unit tracking to input data and model variables, implement automatic coefficient scaling for numerical stability, and integrate SDDP.jl's numerical diagnostics. This ensures that problems with variables of different magnitudes (e.g., MW vs hm3 vs $/MWh) solve reliably and that users can diagnose numerical issues.

## Primary Agent

Split between `hpc-julia-developer` (infrastructure: units registry, solver config) and `sddp-specialist` (numerical optimization: LP scaling, diagnostics).

## Scope

- Variable units system (tracking, validation, conversion)
- LP coefficient scaling / rescaling strategies
- Numerical stability diagnostics integration
- Solver-specific configuration for numerical robustness

## Tickets

| ID         | Title                                            | Estimate | Agent               |
| ---------- | ------------------------------------------------ | -------- | ------------------- |
| ticket-013 | Implement variable units registry and validation | 3 pts    | hpc-julia-developer |
| ticket-014 | Implement automatic LP coefficient scaling       | 4 pts    | sddp-specialist     |
| ticket-015 | Integrate numerical stability diagnostics        | 3 pts    | sddp-specialist     |
| ticket-016 | Add solver configuration options                 | 2 pts    | hpc-julia-developer |

## Dependencies

- Epic 02 must be complete (algorithm flexibility in place)
