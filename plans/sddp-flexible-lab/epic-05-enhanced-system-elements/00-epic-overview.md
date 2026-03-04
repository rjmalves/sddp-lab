# Epic 05: Enhanced System Elements

## Goal

Add new power system elements to model modern energy systems: non-controllable generation (renewable sources with stochastic availability), energy contracts (import/export), and pumping stations (water transfer between reservoirs). Each element integrates with the existing System module architecture, the SDDP subproblem builder, the load balance constraint, the scaling system, and the variable units registry.

## Primary Agent

`sddp-specialist` -- These tickets require deep understanding of LP formulations for power system elements within the SDDP framework: how new variables and constraints affect dual information and cuts, how energy contracts interact with the bus load balance, how pumping stations couple to hydro water balances, and how non-controllable sources with stochastic availability integrate into the SAA mechanism. The `hpc-julia-developer` reviews for type stability and adherence to existing System module patterns.

## Scope

- Non-controllable generation (wind, solar) with stochastic availability profiles
- Energy contracts (import/export) with unidirectional price model
- Pumping stations transferring water between reservoirs with power consumption

## Non-Scope

- Battery energy storage (deferred -- requires SDDP.State for charge/discharge dynamics, higher complexity)
- Demand response (deferred -- interaction with load scenarios not yet designed)
- Fuel supply constraints (deferred -- requires multi-thermal pool linking)

## Tickets

| ID         | Title                                   | Estimate | Agent           |
| ---------- | --------------------------------------- | -------- | --------------- |
| ticket-025 | Add non-controllable generation element | 4 pts    | sddp-specialist |
| ticket-026 | Add energy contracts system element     | 3 pts    | sddp-specialist |
| ticket-027 | Add pumping stations system element     | 4 pts    | sddp-specialist |

## Dependencies

- Epic 04 must be complete

## Reference Specifications

The mathematical formulations and data models for these elements are documented in the POWE.RS specification:

- Equipment formulations: `/home/rogerio/git/powers/docs/specs/01-math/equipment-formulations.md`
- System elements overview: `/home/rogerio/git/powers/docs/specs/01-math/system-elements.md`
- Data models: `/home/rogerio/git/powers/docs/specs/02-data-model/input-system-entities.md`
