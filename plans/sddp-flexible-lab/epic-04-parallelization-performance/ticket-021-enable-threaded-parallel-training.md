# ticket-017 Enable Threaded Parallel Training and Simulation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SDDP.jl parallel scheme thread-safety requirements)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Enable the `SDDP.Threaded()` parallel scheme for both training and simulation, including proper thread count configuration, validation that the thread count does not exceed the number of policy graph nodes, and benchmarking to verify speedup.

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/Engines.jl` (Threaded parallel scheme type), `src/Engines/sddp/input.jl` (constructor), `src/Engines/sddp/train.jl`, `src/Engines/sddp/simulate.jl`
- **Key decisions needed**: Whether thread count is auto-detected or user-specified. How to validate thread availability at runtime.
- **Open questions**:
  - Should SDDPlab warn if Julia was started without `--threads`?
  - How to handle the SDDP.jl requirement that thread count <= number of graph nodes?

## Dependencies

- **Blocked By**: ticket-016 (Epic 03 complete)
- **Blocks**: ticket-018

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
