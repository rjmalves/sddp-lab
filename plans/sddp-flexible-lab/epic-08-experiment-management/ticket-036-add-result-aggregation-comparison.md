# ticket-036 Add Result Aggregation and Comparison Tools

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify comparison metrics are statistically sound for SDDP)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create tools for aggregating results from multiple experiment runs and producing comparison reports. This includes convergence curve overlays, simulation cost distribution comparisons, and summary statistics tables.

## Anticipated Scope

- **Files likely to be modified**: `src/Experiments/Experiments.jl`, new file `src/Experiments/comparison.jl`, new file `src/Experiments/aggregation.jl`
- **Key decisions needed**: Whether comparison outputs are DataFrames, CSVs, or structured JSON. Whether visualization is included (Julia plotting) or deferred to external tools.
- **Open questions**:
  - What comparison metrics are most useful for SDDP experiments?
  - Should this produce publication-ready tables or raw data for external analysis?

## Dependencies

- **Blocked By**: ticket-035
- **Blocks**: ticket-037

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
