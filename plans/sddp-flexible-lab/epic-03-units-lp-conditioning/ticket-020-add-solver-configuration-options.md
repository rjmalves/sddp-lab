# ticket-016 Add Solver Configuration Options

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify solver parameter correctness for LP/MIP)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Enable solver-specific configuration through the JSONC config file, including solver selection, numerical precision parameters (e.g., HiGHS NumericFocus, GLPK tolerances), and method selection (simplex vs barrier). This allows users to tune solver behavior for numerical robustness without changing code.

## Anticipated Scope

- **Files likely to be modified**: `src/study.jl` (solver setup), `src/Engines/Engines.jl` (solver configuration types), new file `src/Engines/solver.jl`, `main.jsonc` examples
- **Key decisions needed**: Whether solver configuration is part of the engine config or a top-level study config. How to handle solver-specific parameters across different solvers (GLPK, HiGHS, Gurobi, CPLEX).
- **Open questions**:
  - Should the solver be specified in the JSONC or passed programmatically?
  - How to handle solver parameters that are specific to one solver backend?
  - Should there be a "solver profile" concept (e.g., "numerical_robust", "fast", "default")?

## Dependencies

- **Blocked By**: ticket-015
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: Low (will be re-estimated during refinement)
