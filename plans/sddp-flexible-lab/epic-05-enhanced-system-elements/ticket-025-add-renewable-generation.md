# ticket-021 Add Renewable Generation System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability and integration with existing System module patterns)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add a `Renewable` system entity type (wind, solar) with stochastic availability factors. Renewables have zero marginal cost, installed capacity, and a time-varying availability profile that can be either deterministic or stochastic. The availability factor is multiplied by installed capacity to produce the maximum generation at each stage.

## Anticipated Scope

- **Files likely to be modified**: `src/System/System.jl` (new type), new files `src/System/renewable.jl`, `src/System/renewable-validators.jl`, `src/Engines/sddp/build.jl` (add_system_elements! for Renewables), `src/Lab/variables.jl` (new symbols), `src/Scenarios/Scenarios.jl` (renewable availability scenarios)
- **Key decisions needed**: Whether renewable availability is a separate stochastic process or part of the existing inflow/load pattern. How to model curtailment (allowing generation below available capacity). Whether to use the same bus-connected topology as thermals.
- **Open questions**:
  - Should renewable output be a state variable or a simple variable with time-varying bounds?
  - How does stochastic availability integrate with the SAA generation?
  - Should curtailment have a penalty cost?

## Dependencies

- **Blocked By**: ticket-020 (Epic 04 complete)
- **Blocks**: ticket-022

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
