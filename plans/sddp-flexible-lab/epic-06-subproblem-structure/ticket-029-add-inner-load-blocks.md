# ticket-029 Add Inner Load Blocks (Parallel and Chronological)

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify LP size impact, JuMP variable/constraint indexing, and performance)

## Context

### Background

After ticket-028 establishes proper time duration awareness with a single block per stage, this ticket generalizes the LP formulation to support multiple inner load blocks within each stage. Each block represents a time interval (e.g., "peak", "off-peak", "shoulder") with its own duration tau*k, load level D*{b,k}, and per-block decision variables. Two modes are supported: parallel blocks (default, single water balance per hydro with block-weight aggregation) and chronological blocks (sequential water balances with intra-stage storage dynamics). The reference specifications are in block-formulations.md and equipment-formulations.md.

### Relation to Epic

This is the second ticket of Epic 06. It builds directly on ticket-028's tau/zeta infrastructure, extending it from a single block to K blocks. The block structure affects every system element's variable dimensionality, the load balance constraint (one per bus per block), the objective function (sum over blocks with tau_k weighting), and the hydro water balance (parallel vs. chronological formulation). This is the largest and most cross-cutting change in the epic.

### Current State

After ticket-028, the subproblem builder will:

- Compute `tau` (single value) and `zeta` from graph node datetimes
- Pass `tau` to `add_system_objective!` which multiplies all cost terms by tau
- Pass `zeta` to `add_hydro_balance!` which multiplies flow terms by zeta
- All JuMP variables are 1D indexed by entity: `m[THERMAL_GENERATION][n]` for n in 1:num_thermals

Key files (post ticket-028):

- `src/Engines/sddp/build.jl`: All `add_system_elements!` methods create 1D variables; `__add_load_balance!` creates one constraint per bus; `add_system_objective!` has a single tau multiplier; `add_hydro_balance!` has a single zeta factor.
- `src/Scenarios/load.jl`: `DeterministicLoad` stores (bus_id, node_id, value) triples -- single load per bus per node, no block dimension.
- `src/Scenarios/Scenarios.jl`: `get_load(bus_id, node_id, scenarios)` returns a single Real value.

## Specification

### Requirements

#### Block Configuration

1. **Block data structure**: Define a `Block` struct with fields `name::String` and `duration_hours::Float64`. Define a `BlockConfig` holding `mode::Symbol` (`:parallel` or `:chronological`) and `blocks::Vector{Block}`.
2. **Default behavior**: When no blocks are configured, use a single implicit block with duration = stage duration (backward compatible with ticket-028).
3. **Configuration source**: Block definitions come from the scenarios configuration JSON under a new optional `"blocks"` key:
   ```json
   {
     "blocks": {
       "mode": "parallel",
       "definitions": [
         { "name": "LEVE", "duration_hours": 200 },
         { "name": "MEDIA", "duration_hours": 300 },
         { "name": "PESADA", "duration_hours": 228 }
       ]
     }
   }
   ```
4. **Validation**: Sum of block durations must equal the stage duration (from graph node datetimes). Mode must be "parallel" or "chronological".

#### Variable Indexing

5. **All power/flow decision variables become 2D**: `[entity, block]` instead of `[entity]`. This affects:
   - `THERMAL_GENERATION[j, k]`
   - `DEFICIT[b, k]`
   - `DIRECT_EXCHANGE[l, k]`, `REVERSE_EXCHANGE[l, k]`
   - `NC_GENERATION[r, k]`
   - `CONTRACT_DISPATCH[c, k]`
   - `PUMPED_FLOW[p, k]`
   - `HYDRO_GENERATION[h, k]`, `TURBINED_FLOW[h, k]`, `SPILLAGE[h, k]`, `OUTFLOW[h, k]`
   - `HYDRO_MIN_GENERATION_SLACK[h, k]`
   - `PUMP_POWER[p, k]` (expression)
   - `NC_CURTAILMENT[r, k]` (expression)
   - `THERMAL_GENERATION_COST[j, k]` (expression)
   - `NET_EXCHANGE[l, k]` (expression)
6. **State variables remain 1D**: `STORED_VOLUME[h]` is still indexed by hydro only (end-of-stage storage).
7. **Inflow variables remain 1D**: `INFLOW[h]`, `omega_INFLOW[h]`, `STCHP[n]` -- the AR model operates at stage level, not block level.

#### Load Balance

8. **One load balance per bus per block**: `__add_load_balance!` generates `num_buses * num_blocks` constraints, each using block-indexed variables and block-specific load `D_{b,k}`.
9. **Load data extension**: The `DeterministicLoad` data model must be extended to support per-block loads. When blocks are defined, the load CSV must include a `block` column. When no blocks are defined, existing format works (single load = single block).

#### Objective Function

10. **Sum over blocks with tau_k weighting**: The objective becomes `sum_k tau_k * [cost terms for block k]`. In the single-block case, this degenerates to `tau * [cost terms]` (identical to ticket-028).

#### Water Balance -- Parallel Mode

11. **Single water balance per hydro** with block-weight aggregation:
    ```
    v_h = v_hat_h + zeta * [a_h + sum_k w_k * (upstream_outflow_{h,k} - outflow_{h,k} +/- pumping_{h,k})]
    ```
    where `w_k = tau_k / sum(tau_j)` and `zeta = 0.0036 * sum(tau_k)`.

#### Water Balance -- Chronological Mode

12. **Per-block water balance** with intermediate storage variables:
    - Additional variables: `v_{h,k}` for k = 1..|K|-1 (intermediate block storage, bounded same as `v_h`)
    - Block 1: `v_{h,1} = v_hat_h + zeta_1 * [a_h * w_1 + net_flows_{h,1}]`
    - Block k (k>1): `v_{h,k} = v_{h,k-1} + zeta_k * [a_h * w_k + net_flows_{h,k}]`
    - State linkage: `v_h = v_{h,|K|}` (end-of-last-block storage equals the SDDP state variable)
    - Where `zeta_k = 0.0036 * tau_k`
13. **Intermediate storage NOT a state variable**: Only end-of-stage `v_h` is an SDDP.State. Intermediate `v_{h,k}` are regular JuMP variables.

#### Scaling

14. **Scaling system must handle 2D variables**: The `apply_scaling` function scales entity parameters (capacities, costs). Since variables are now 2D, the per-entity parameter scaling still applies uniformly across blocks (same thermal max generation in every block). No changes to `compute_scaling_factors` or `apply_scaling` are needed because the parameters themselves do not change -- only the JuMP variable dimensions change.
15. **Unscaling simulation results**: The `_get_variable_unscale_factor` and `__write_simulation_results` must handle 2D variable data in simulation output. The simulation output from SDDP.jl will now contain matrices instead of vectors for block-indexed variables.

### Inputs/Props

- `blocks::Vector{Block}`: Block definitions (name + duration_hours)
- `block_mode::Symbol`: `:parallel` or `:chronological`
- `tau_k::Vector{Float64}`: Duration of each block in hours
- `w_k::Vector{Float64}`: Block weights (tau_k / sum(tau_k))
- `zeta::Float64`: Total time conversion = 0.0036 \* sum(tau_k) (parallel mode)
- `zeta_k::Vector{Float64}`: Per-block time conversion = 0.0036 \* tau_k (chronological mode)

### Outputs/Behavior

- When blocks are configured, simulation output contains 2D arrays indexed by (entity, block) for all power/flow variables.
- When no blocks are configured (single block), behavior is identical to ticket-028.
- Block names appear as a new dimension in simulation output files.

### Error Handling

- If sum(block durations) does not match stage duration: emit `AssertionError` with message indicating the mismatch.
- If mode is not "parallel" or "chronological": emit `ErrorException` for invalid mode.
- If blocks have duplicate names: emit `AssertionError`.
- If load data does not have block dimension when blocks are configured: emit `ErrorException` explaining the missing block column.

## Acceptance Criteria

1. Given a scenario config with no `"blocks"` key, when the model is built, then behavior is identical to ticket-028 (single block, single tau, single zeta).
2. Given 3 blocks (200h, 300h, 228h) in parallel mode, when the model is built, then `tau_k = [200, 300, 228]`, `w_k = [200/728, 300/728, 228/728]`, and `zeta = 0.0036 * 728 = 2.6208`.
3. Given parallel block mode, when the water balance is examined, then there is exactly 1 constraint per hydro, and the flow terms are weighted by `zeta * w_k`.
4. Given chronological block mode with 3 blocks, when the water balance is examined, then there are 3 constraints per hydro (one per block), with intermediate storage variables `v_{h,1}`, `v_{h,2}`, and `v_h = v_{h,3}`.
5. Given block-indexed variables, when `add_system_elements!` is called for thermals, then `THERMAL_GENERATION` is a 2D JuMP variable `[1:num_thermals, 1:num_blocks]`.
6. Given 3 blocks and 2 buses, when `__add_load_balance!` is called, then 6 load balance constraints are created (2 buses \* 3 blocks).
7. Given block-indexed variables, when the objective is built, then the objective sums over blocks: `sum_k tau_k * [terms for block k]`.
8. Given the existing 1dtoy example with no blocks config, when build/train/simulate is run, then the model works without errors (backward compatibility).
9. Given a new example with 3 blocks in parallel mode, when build/train (3 iterations) is run, then the model solves without errors.

## Implementation Guide

### Suggested Approach

This is a large ticket. Implement in this order:

**Phase 1: Block configuration parsing**

1. Create `Block` struct and `BlockConfig` in `src/Scenarios/Scenarios.jl` (or a new `src/Scenarios/blocks.jl`).
2. Add optional `"blocks"` key parsing in `src/Scenarios/scenariosdata.jl` constructor. Default: single block with mode=:parallel.
3. Add validation schema for block definitions.
4. Store `BlockConfig` on `ScenariosData` (add a field, or derive it from graph + config).

**Phase 2: Extend load data**

5. Extend `DeterministicLoad` to support per-block loads. Add optional `block` column to load CSV. When absent, all load goes to block 1 (single block).
6. Change `get_load(bus_id, node_id, scenarios)` to `get_load(bus_id, node_id, block_idx, scenarios)` (or return a vector of per-block loads).

**Phase 3: 2D variable creation**

7. Modify all `add_system_elements!` methods to create 2D JuMP variables `[entity, block]` when `num_blocks > 1`. When `num_blocks == 1`, use 1D (backward compat) or always use 2D with dim 1 (simpler code but changes variable shapes).
   - **Decision**: Always use 2D `[entity, block]`. Even for single block, this avoids branching everywhere. The 2D-with-K=1 case is mathematically identical.
   - Pass `num_blocks::Int` as an argument to all `add_system_elements!` methods.

**Phase 4: Block-aware load balance**

8. Modify `__add_load_balance!` to iterate over blocks, creating one constraint per (bus, block). The load value `D_{b,k}` comes from the extended load data.

**Phase 5: Block-aware objective**

9. Modify `add_system_objective!` to sum over blocks with `tau_k` weighting.

**Phase 6: Block-aware water balance**

10. Implement parallel water balance: single constraint per hydro, block-weighted flow terms.
11. Implement chronological water balance: per-block constraints with intermediate storage.
12. Dispatch on `block_mode` to choose the formulation.

**Phase 7: Simulation output**

13. Update `save_simulation.jl` to handle 2D variable data in simulation output.

### Key Files to Modify

| File                                  | Changes                                                                                                                                                                                                                                        |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/Scenarios/Scenarios.jl`          | Add `Block` struct, `BlockConfig`, add to `ScenariosData` or expose via accessor                                                                                                                                                               |
| `src/Scenarios/scenariosdata.jl`      | Parse optional `"blocks"` config                                                                                                                                                                                                               |
| `src/Scenarios/load.jl`               | Extend `DeterministicLoad` for per-block loads                                                                                                                                                                                                 |
| `src/Scenarios/load-validators.jl`    | Validate per-block load format                                                                                                                                                                                                                 |
| `src/Engines/sddp/build.jl`           | Major: all `add_system_elements!` (2D vars), `add_hydro_balance!` (parallel/chronological), `__add_load_balance!` (per-block), `add_system_objective!` (sum over blocks), `__generate_subproblem_builder` (compute tau_k/w_k/zeta from blocks) |
| `src/Engines/sddp/save_simulation.jl` | Handle 2D variable data in simulation output                                                                                                                                                                                                   |
| `src/Engines/sddp/scaling.jl`         | No changes expected (scaling applies to entity parameters, not block dimensions)                                                                                                                                                               |
| `src/Lab/variables.jl`                | Possibly add `BLOCK_STORAGE` symbol for chronological intermediate storage                                                                                                                                                                     |
| `test/test-load-blocks.jl`            | New test file                                                                                                                                                                                                                                  |

### Patterns to Follow

- Follow the `add_system_elements!(m, ses::EntityType)` pattern from build.jl lines 40-191 -- just add a `num_blocks` parameter and use 2D `@variable` syntax: `JuMP.@variable(m, [1:num_entities, 1:num_blocks], ...)`.
- Follow the existing `__add_load_balance!` pattern (lines 456-495) but wrap with an outer block loop.
- For chronological water balance, the intermediate storage variables follow the same pattern as `STORED_VOLUME` but are NOT `SDDP.State` -- just regular bounded variables.
- For block mode dispatch, use Julia method dispatch on a type (e.g., `add_hydro_balance!(m, hydros, ..., mode::ParallelBlocks, ...)` vs `add_hydro_balance!(m, hydros, ..., mode::ChronologicalBlocks, ...)`).

### Pitfalls to Avoid

- **Do NOT create SDDP.State variables for intermediate block storage.** Only end-of-stage `v_h` is a state variable. Intermediate `v_{h,k}` are regular JuMP variables. This is critical for correct SDDP cut generation.
- **Do NOT change the AR model constraints.** The inflow model operates at stage level. Block weights `w_k` apply in the water balance, not in the AR constraint.
- **Be careful with the single-block backward compatibility.** When no blocks are configured, the behavior must be identical to ticket-028. Test this explicitly.
- **Beware of JuMP 2D variable indexing.** `JuMP.@variable(m, x[1:N, 1:K])` creates a Matrix-like structure. Access is `m[:x][n, k]`. Expressions like `m[THERMAL_GENERATION][n, k]` must be valid.
- **The SDDP.parameterize callback** should NOT change. `JuMP.fix.(m[omega_INFLOW], omega)` fixes 1D inflow variables (one per hydro). Block allocation happens in the water balance.
- **Performance**: The LP size increases linearly with `num_blocks`. For 3 blocks, expect ~3x more variables and constraints. This is expected and acceptable.

## Testing Requirements

### Test Protocol

- **ALWAYS** use `TEST_FILTER="test-load-blocks"` with 120000ms Bash timeout for unit tests
- **NEVER** run `test-main` without 360000ms timeout
- Create a NEW test file `test/test-load-blocks.jl`
- Use HiGHS for solver-dependent tests

### Unit Tests

Create `test/test-load-blocks.jl`:

1. **Block config parsing**: Given valid block JSON, verify Block and BlockConfig construction.
2. **Block config validation**: Given invalid block JSON (bad mode, missing durations, mismatched total), verify error accumulation.
3. **Default single block**: Given no blocks config, verify single block with tau = stage duration.
4. **2D variable creation**: Build a model with 3 blocks and 2 thermals, verify `THERMAL_GENERATION` is `[2, 3]`.
5. **Per-block load balance**: Build with 2 buses and 3 blocks, verify 6 load balance constraints.
6. **Parallel water balance**: Build with 2 hydros and 3 blocks in parallel mode, verify 2 hydro balance constraints (one per hydro) with weighted flow terms.
7. **Chronological water balance**: Build with 2 hydros and 3 blocks in chronological mode, verify 6 hydro balance constraints (2 hydros _ 3 blocks) and 4 intermediate storage variables (2 hydros _ 2 intermediate blocks).
8. **Objective sum over blocks**: Build with 3 blocks, verify objective includes `sum_k tau_k * cost * gen[n,k]`.

### Integration Tests

9. **Backward compatibility**: Run 1dtoy example (no blocks), verify identical behavior to ticket-028.
10. **Parallel blocks e2e**: Run a modified 1dtoy with 3 blocks in parallel mode, build/train(3 iter), verify no errors.

## Dependencies

- **Blocked By**: ticket-028 (time duration must be in place before blocks)
- **Blocks**: None within epic-06; later epics may depend on block infrastructure

## Effort Estimate

**Points**: 5
**Confidence**: Medium
