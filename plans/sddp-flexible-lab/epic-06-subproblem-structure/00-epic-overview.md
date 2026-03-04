# Epic 06: Subproblem Structure and Stochastic Improvements

## Goal

Introduce fundamental changes to the SDDP subproblem structure: stage time duration awareness (converting MW-based costs to MWh-based costs via block durations), inner load blocks (decomposing each stage into multiple time intervals with their own balance constraints), and inflow non-negativity methods (preventing physically impossible negative inflows from the AR model). These changes deepen the mathematical fidelity of the LP formulation and are prerequisites for more realistic energy system modeling.

## Primary Agent

`sddp-specialist` -- These tickets require deep understanding of SDDP subproblem structure: how block decomposition affects water balances and cut generation, how time duration conversion interacts with all existing cost terms, and how inflow non-negativity methods affect LP feasibility and dual values. The `hpc-julia-developer` reviews for type stability, performance impact of the enlarged LP, and consistency with the build pipeline.

## Scope

- Stage time duration awareness and MW-to-MWh cost conversion via `tau_k`
- Inner load blocks (parallel and chronological modes) with block-level balance constraints
- Inflow non-negativity methods: none, penalty, truncation, truncation with penalty

## Tickets

| ID         | Title                                              | Estimate | Agent           |
| ---------- | -------------------------------------------------- | -------- | --------------- |
| ticket-028 | Add stage time duration and MW-to-MWh conversion   | 4 pts    | sddp-specialist |
| ticket-029 | Add inner load blocks (parallel and chronological) | 5 pts    | sddp-specialist |
| ticket-030 | Add inflow non-negativity methods                  | 3 pts    | sddp-specialist |

## Dependencies

- Epic 05 must be complete (system elements provide the LP variables that time duration and blocks act upon)

## Reference Specifications

- Notation and time conversion: `/home/rogerio/git/powers/docs/specs/00-overview/notation-conventions.md`
- Block formulations: `/home/rogerio/git/powers/docs/specs/01-math/block-formulations.md`
- Inflow non-negativity: `/home/rogerio/git/powers/docs/specs/01-math/inflow-nonnegativity.md`
- Equipment formulations (tau_k in objectives): `/home/rogerio/git/powers/docs/specs/01-math/equipment-formulations.md`
