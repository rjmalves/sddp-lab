# ticket-022 Add Battery Energy Storage System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify SDDP.State variable implementation and type stability)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add a `Battery` system entity type with charge/discharge dynamics, round-trip efficiency, and state-of-charge as a state variable. Batteries provide temporal flexibility in the dispatch problem, allowing energy to be shifted between periods.

## Anticipated Scope

- **Files likely to be modified**: `src/System/System.jl`, new files `src/System/battery.jl`, `src/System/battery-validators.jl`, `src/Engines/sddp/build.jl` (add_system_elements! for Batteries), `src/Lab/variables.jl` (CHARGE, DISCHARGE, STATE_OF_CHARGE symbols)
- **Key decisions needed**: Whether charge and discharge are separate variables or net charge. How round-trip efficiency is modeled (on charge, discharge, or split). Whether self-discharge is included.
- **Open questions**:
  - Should state-of-charge use SDDP.State (like hydro storage) or a different formulation?
  - How does battery degradation factor in, if at all?
  - What is the bus connection model for batteries?

## Dependencies

- **Blocked By**: ticket-021
- **Blocks**: ticket-023

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
