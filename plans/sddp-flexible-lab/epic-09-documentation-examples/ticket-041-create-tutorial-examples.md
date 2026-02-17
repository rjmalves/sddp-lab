# ticket-037 Create Tutorial Examples for Advanced Features

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify examples run correctly and follow Julia best practices)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create a set of tutorial example cases that demonstrate advanced features: different risk measures, parallel training, renewable generation, battery storage, Markov chain scenarios, multi-configuration experiments, and convergence analysis. Each tutorial should be a self-contained example directory with annotated configuration files and a tutorial document.

## Anticipated Scope

- **Files likely to be modified**: `example/` (new example directories), `docs/src/tutorials/` (tutorial pages)
- **Key decisions needed**: Which features are most important to demonstrate. How complex the tutorial examples should be.
- **Open questions**:
  - Should tutorials be Jupyter notebooks, Literate.jl scripts, or plain markdown?
  - How many tutorial examples are needed to cover the major features?
  - Should tutorials build on each other or be fully independent?

## Dependencies

- **Blocked By**: ticket-036
- **Blocks**: None

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
