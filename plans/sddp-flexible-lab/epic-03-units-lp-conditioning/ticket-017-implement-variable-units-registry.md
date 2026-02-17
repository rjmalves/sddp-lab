# ticket-013 Implement Variable Units Registry and Validation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify unit choices match energy systems conventions)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create a units system that tracks physical units (MW, m3/s, hm3, $/MWh, hours, etc.) for each variable and parameter in the input data. The system should validate unit consistency during model building and enable automatic unit conversion when combining quantities. This addresses a core numerical stability concern: variables with wildly different magnitudes cause LP solver issues.

## Anticipated Scope

- **Files likely to be modified**: `src/Lab/variables.jl`, `src/Lab/types.jl`, `src/System/hydro.jl`, `src/System/thermal.jl`, `src/System/bus.jl`, `src/Engines/sddp/build.jl`, new file `src/Utils/units.jl`
- **Key decisions needed**: Whether units are tracked at the type level (parametric types) or at the value level (wrapper struct). Whether conversion factors are rational or floating-point. How units are specified in JSONC input files.
- **Open questions**:
  - Should units be mandatory in input files or optional with defaults?
  - Should the system support derived units (e.g., MWh = MW \* h) or only base units?
  - How should unit mismatches be reported -- as warnings or hard errors?

## Dependencies

- **Blocked By**: ticket-012 (Epic 02 complete)
- **Blocks**: ticket-014

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
