# ticket-045 Update Subproblem Builder for Per-Stage Blocks

## Context

### Background

The subproblem builder in `src/Engines/sddp/build.jl` currently reads a single global `BlockConfig` once (line 799: `block_config = get_block_config(scenarios)`) and uses the same block mode and block count `K` for every SDDP node's subproblem. After ticket-044 restructures `BlockConfig` to be per-stage, the builder must look up the correct `BlockConfig` for each node's stage and support varying block counts across stages.

### Relation to Epic

This is the core mathematical ticket of Epic 11. It ensures the LP formulation uses the correct per-stage block structure for variable creation, water balance constraints, load balance, and objective function terms.

### Current State

In `__generate_subproblem_builder` (line 792-916 of `build.jl`):

- Line 799: `block_config = get_block_config(scenarios)` -- single global read
- Line 858: `block_mode = block_config.mode` -- single global mode
- Line 859: `K = num_blocks(block_config)` -- single global K
- Line 876: `tau_k = get_block_durations(block_config, tau)` -- inside the closure, uses global config
- Line 878: `add_system_elements!(m, system, K)` -- uses global K
- Line 880: `add_hydro_balance!(...)` with global `block_mode` and `K`
- Line 910: `add_system_objective!(m, system, tau_k, method, scaling)` -- uses tau_k derived from global config

All `add_system_elements!` methods (lines 41-229) take `num_blocks::Int` as a parameter, which is already per-call, so they do not need structural changes.

## Specification

### Requirements

1. Move the `block_config` lookup from the outer scope (line 799) to inside the `fun_sp_build` closure, keyed by the current node's stage
2. Compute `block_mode`, `K`, and `tau_k` per-node inside `fun_sp_build` using `get_block_config(scenarios, stage)`
3. Pass the per-stage `K` to `add_system_elements!`, `add_hydro_balance!`, and `__add_load_balance!`
4. Pass the per-stage `block_mode` to `add_hydro_balance!`
5. Add a build-time validation: for each stage, if blocks are explicitly configured, verify `abs(sum(tau_k) - tau) <= 1e-3` (tolerance of 1 millisecond in hours). If validation fails, `@warn` with the stage index, expected tau, and actual sum.
6. The `K` variable used in the outer scope (line 859) for pre-allocating maps must be removed or replaced -- all block-count-dependent logic must move inside the closure

### Inputs/Props

- `ScenariosData` with `block_configs::Dict{Int, BlockConfig}` (from ticket-044)
- Per-node stage index from `__extract_stage(node)`

### Outputs/Behavior

- Each SDDP subproblem is built with the correct number of blocks for its stage
- A stage with 2 blocks creates 2-column block-indexed variables; a stage with 3 blocks creates 3-column block-indexed variables
- Water balance mode (parallel vs chronological) can differ per stage

### Error Handling

- If block duration sum deviates from stage tau by more than 1e-3 hours, emit `@warn "Stage $stage: block durations sum to $(sum_tau_k) hours but stage duration is $tau hours"`
- If `get_block_config(scenarios, stage)` returns `default_block_config()` (no explicit blocks), proceed with K=1 as before

## Acceptance Criteria

- [ ] Given a `ScenariosData` with stage 1 having 2 parallel blocks and stage 2 having 3 chronological blocks, when `Lab.build(engine, files, optimizer)` is called, then the subproblem at stage 1 has `THERMAL_GENERATION` of size `(N_thermals, 2)` and the subproblem at stage 2 has `THERMAL_GENERATION` of size `(N_thermals, 3)`
- [ ] Given a `ScenariosData` with stage 1 having 2 parallel blocks and stage 2 having 3 chronological blocks, when `Lab.build` is called, then the subproblem at stage 1 has `HYDRO_BALANCE` of size `(N_hydros,)` (parallel) and stage 2 has `HYDRO_BALANCE` of size `(N_hydros, 3)` (chronological)
- [ ] Given a `ScenariosData` with no blocks configured for any stage, when `Lab.build` is called, then all subproblems have K=1 block-indexed variables (identical to current behavior)
- [ ] Given a `ScenariosData` with block durations summing to a value different from stage tau by more than 1e-3, when `Lab.build` is called, then a `@warn` is emitted containing the stage index and the mismatch values
- [ ] Given the existing `1dtoy` example case (no blocks), when `Lab.build` followed by `Lab.train` and `Lab.simulate` are called, then the run completes without error and produces results identical to the current behavior

## Implementation Guide

### Suggested Approach

1. In `__generate_subproblem_builder`, remove lines 799, 858-859 (the global `block_config`, `block_mode`, `K` reads)
2. Inside the `fun_sp_build` closure (line 863), after computing `stage` and `tau`, add:
   ```julia
   stage_block_config = get_block_config(scenarios, stage)
   block_mode = stage_block_config.mode
   K = num_blocks(stage_block_config)
   tau_k = get_block_durations(stage_block_config, tau)
   ```
3. Add the duration validation:
   ```julia
   if has_blocks(stage_block_config) && abs(sum(tau_k) - tau) > 1e-3
       @warn "Stage $stage: block durations sum to $(sum(tau_k)) hours but stage duration is $tau hours"
   end
   ```
4. Remove the `tau_k = get_block_durations(block_config, tau)` from line 876 (now computed above)
5. Pass `K` and `block_mode` to `add_system_elements!`, `add_hydro_balance!`, and `__add_load_balance!` -- these already accept `num_blocks::Int` as a parameter, so only the source of `K` changes
6. Verify that no outer-scope code depends on the removed `K` variable (search for uses of `K` outside the closure)

### Key Files to Modify

- `src/Engines/sddp/build.jl` -- `__generate_subproblem_builder` function (lines 792-916), specifically the outer scope (lines 799, 858-859) and the inner closure (lines 863-913)

### Patterns to Follow

- The existing pattern of extracting `start_dt, end_dt` per-node from `stage_datetimes` / `node_datetimes` (lines 867-873) is the model for per-node config lookup
- The existing `tau` computation (line 875) and `tau_k` derivation (line 876) pattern continues, just with per-stage config

### Pitfalls to Avoid

- Do NOT create block-indexed variables in the outer scope -- all variable creation happens inside `fun_sp_build` which already receives a fresh `JuMP.Model` per node
- Do NOT assume `K` is constant across stages in any pre-allocated data structures in the outer scope
- The `SAA` dict (line 814) is NOT block-indexed, so it does not need per-stage-K changes
- The scaling factor applications (lines 816-823) are NOT block-indexed, so they are unaffected

### Out of Scope

- Changing the `ScenariosData` struct or parsing (ticket-044)
- Changing the output format (ticket-046)
- Adding new test cases (ticket-047)

## Testing Requirements

### Unit Tests

- Test `fun_sp_build` closure with mock `ScenariosData` having different `BlockConfig` per stage: verify variable dimensions differ across stages
- Test duration validation warning is emitted when block durations mismatch stage tau

### Integration Tests

- Build a full SDDP model with per-stage blocks using `SDDP.LinearPolicyGraph` and verify subproblem variable dimensions per stage

### E2E Tests

- Deferred to ticket-047

## Dependencies

- **Blocked By**: ticket-044-restructure-blockconfig-per-stage.md
- **Blocks**: ticket-046-reform-output-parquet-block-columns.md, ticket-047-update-tests-examples-per-stage-blocks.md

## Effort Estimate

**Points**: 4
**Confidence**: High
