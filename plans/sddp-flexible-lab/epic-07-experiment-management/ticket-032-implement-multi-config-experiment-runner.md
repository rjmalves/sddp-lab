# ticket-028 Implement Multi-Configuration Experiment Runner

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify experiment design covers meaningful SDDP parameter variations)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create an experiment runner that takes multiple JSONC configuration files (or a single file with multiple engine configurations) and runs the full pipeline for each, collecting results for comparison. This enables systematic comparison of algorithm variations (e.g., different risk measures, stopping criteria, cut types) on the same problem instance.

## Anticipated Scope

- **Files likely to be modified**: new module `src/Experiments/Experiments.jl`, `src/study.jl` (multi-study orchestration), new file `src/Experiments/runner.jl`
- **Key decisions needed**: Whether experiments are defined as multiple main.jsonc files or as a single experiment.jsonc with config overrides. How results are structured for comparison.
- **Open questions**:
  - Should experiments run sequentially or in parallel?
  - How to handle shared vs. independent models (rebuild for each config or share model)?
  - What is the output format for experiment results?

## Dependencies

- **Blocked By**: ticket-027 (Epic 06 complete)
- **Blocks**: ticket-029

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
