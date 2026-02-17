# ticket-024 Add Fuel Supply Constraints

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify multi-thermal fuel pool linking implementation)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add fuel supply constraints that limit the total fuel available to thermal generators over a period. This models fuel contracts, gas pipeline capacity limits, and seasonal fuel availability. Multiple thermals can share a fuel pool with a joint constraint.

## Anticipated Scope

- **Files likely to be modified**: `src/System/System.jl`, new files `src/System/fuel.jl`, `src/System/fuel-validators.jl`, `src/Engines/sddp/build.jl`, `src/Lab/variables.jl`
- **Key decisions needed**: Whether fuel is modeled as a state variable (inventory) or a per-period constraint. Whether fuel cost is separate from thermal generation cost.
- **Open questions**:
  - Should fuel constraints be multi-period (inventory that depletes over time)?
  - How to link thermals to fuel pools (many-to-one mapping)?
  - Should fuel supply be stochastic?

## Dependencies

- **Blocked By**: ticket-023
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
