# ticket-040 Add Subproblem Debugging Utilities

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify JuMP model introspection and file I/O)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add utilities for inspecting and debugging individual SDDP subproblems, including writing subproblems to files (LP/MPS format), computing deterministic equivalents for small problems, and inspecting decision rules and value functions at specific nodes.

## Anticipated Scope

- **Files likely to be modified**: new file `src/Engines/sddp/debug.jl`, `src/Engines/Engines.jl` (debug configuration)
- **Key decisions needed**: Whether debugging tools are invoked programmatically or via configuration. What file formats to support for subproblem export.
- **Open questions**:
  - Should `SDDP.write_subproblem_to_file()` be integrated for every node or user-selected nodes?
  - Should `SDDP.deterministic_equivalent()` be exposed for small test problems?
  - How to present value function information (cuts at a given state)?

## Dependencies

- **Blocked By**: ticket-039
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: Low (will be re-estimated during refinement)
