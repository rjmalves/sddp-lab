# ticket-023 Add Demand Response System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify constraint implementation follows existing patterns)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add a demand response / flexible load system element that allows a portion of bus load to be shifted or curtailed at a cost. This models programs where consumers reduce consumption during peak periods in exchange for compensation.

## Anticipated Scope

- **Files likely to be modified**: `src/System/System.jl`, new files `src/System/demand-response.jl`, `src/System/demand-response-validators.jl`, `src/Engines/sddp/build.jl`, `src/Lab/variables.jl`
- **Key decisions needed**: Whether demand response is modeled as load reduction (subtractive from bus load) or as a virtual generator. Whether shifted load must be recovered in subsequent periods.
- **Open questions**:
  - What parameters define a demand response program (max curtailment %, cost, recovery period)?
  - How does demand response interact with the load balance constraint?

## Dependencies

- **Blocked By**: ticket-022
- **Blocks**: ticket-024

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
