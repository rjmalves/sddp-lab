# ticket-029 Add Inner Load Blocks (Parallel and Chronological)

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify LP size impact, JuMP variable/constraint indexing, and performance)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Decompose each stochastic stage into multiple inner load blocks (time intervals within the stage) that each require their own energy balance constraints and per-block decision variables. Support two modes:

### Parallel Blocks (default)

All blocks within a stage are independent. A single water balance per hydro spans all blocks using block weights `w_k`. This is the simpler mode with a smaller LP, suitable for long-term strategic planning.

**Water balance**: `v_h = v_hat_h + zeta * [a_h + sum_k w_k * net_flows_{h,k}]`

### Chronological Blocks

Blocks are sequential within a stage with intra-stage storage dynamics. Each block has its own water balance, and storage carries forward from one block to the next.

**Block 1**: `v_{h,1} = v_hat_h + zeta_1 * [a_h * w_1 + net_flows_{h,1}]`
**Block k**: `v_{h,k} = v_{h,k-1} + zeta_k * [a_h * w_k + net_flows_{h,k}]`
**State variable**: `v_h = v_{h,|K|}` (end of last block only)

Additional variables: `v_{h,k}` = storage at end of block k (internal LP variables, NOT state variables).
Additional LP size: `N_hydro * (|K| - 1)` additional variables and constraints.

### Key Design Considerations

- All existing system element `add_system_elements!` methods must be adapted to create per-block variables (indexed by `[entity, block]` instead of just `[entity]`)
- The `__add_load_balance!` function must generate one constraint per bus per block
- The `add_system_objective!` function must sum over blocks with `tau_k` weighting
- The `SDDP.parameterize` call must handle per-block uncertainty (or replicate inflow across blocks with block weights)
- Configuration: `modeling.block_mode = "parallel"` or `"chronological"`

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (major: all `add_system_elements!` methods, `add_hydro_balance!`, `__add_load_balance!`, `add_system_objective!`, `__generate_subproblem_builder`), `src/Scenarios/Scenarios.jl` (block-indexed load data), `src/Engines/Engines.jl` (block mode config type), `src/Engines/sddp/input.jl` (parse block mode), `src/Lab/variables.jl` (block-indexed variable symbols)
- **Key decisions needed**:
  - How to index JuMP variables by (entity, block) -- 2D arrays or separate variables per block?
  - Whether block-indexed loads are specified in the existing load CSV or a new format
  - How the SAA parameterization works with multiple blocks (same inflow replicated across blocks with weights, or separate inflow per block?)
  - How chronological block storage variables interact with SDDP.jl's state variable API (only end-of-stage storage is an SDDP.State; intermediate storages are regular LP variables)
  - How the scaling system handles per-block variables
- **Open questions**:
  - Should this ticket implement both parallel and chronological modes, or should chronological be a separate follow-up ticket?
  - How do transmission line flows interact with blocks (same line limits per block, or different)?
  - How do contract dispatches interact with blocks (contract per block, or aggregate)?
  - What is the performance impact of the enlarged LP on training time? (Need benchmarks)

## Dependencies

- **Blocked By**: ticket-028 (time duration must be in place before blocks)
- **Blocks**: None (within epic-06); ticket-030 is independent of this ticket

## Effort Estimate

**Points**: 5
**Confidence**: Low (will be re-estimated during refinement)
