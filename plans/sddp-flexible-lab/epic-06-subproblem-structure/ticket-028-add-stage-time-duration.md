# ticket-028 Add Stage Time Duration and MW-to-MWh Conversion

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify integration with existing build pipeline, scaling system, and variable units registry)

## Context

### Background

SDDPlab currently formulates the LP subproblem with implicit "unit time" duration: all cost terms use $/MW (or $/m3/s) as though each stage has duration 1, and the water balance omits the flow-to-volume conversion factor zeta. This means costs are expressed per unit power rather than per unit energy (MWh), and the hydro water balance does not properly convert flows (m3/s) to volumes (hm3). The reference specification (notation-conventions.md Section 3.1, lp-formulation.md Section 2) requires all objective terms to be multiplied by tau_k (block duration in hours) and the water balance to use zeta = 0.0036 \* sum(tau_k). This ticket adds proper time duration awareness for the single-block case, where tau = stage duration computed from graph node datetimes.

### Relation to Epic

This is the first ticket of Epic 06 (Subproblem Structure). It establishes the fundamental time-aware LP formulation that ticket-029 (inner load blocks) will generalize to multiple blocks and ticket-030 (inflow non-negativity) will use for penalty cost calculations. Without this ticket, the LP does not produce costs in proper monetary units ($) and water balances are dimensionally incorrect.

### Current State

The subproblem builder in `src/Engines/sddp/build.jl` currently:

1. `add_system_objective!` (lines 227-255): Multiplies each variable directly by its cost coefficient (e.g., `thermals[n].cost * m[THERMAL_GENERATION][n]`) without any time duration multiplier.
2. `add_hydro_balance!` (lines 193-214): Sets `v_h.out == v_h.in - OUTFLOW + INFLOW + upstream_outflow +/- pumping` without the zeta conversion factor, treating flows as if they were already in volume units.
3. `__generate_subproblem_builder` (lines 393-454): Builds the subproblem per node but does not extract `start_datetime`/`end_datetime` from graph nodes.

Graph nodes already store `start_datetime::DateTime` and `end_datetime::DateTime` (defined in `src/Scenarios/Scenarios.jl` line 20-24), validated to have end > start in `src/Scenarios/graph-validators.jl` lines 38-44.

## Specification

### Requirements

1. **Compute stage duration per node**: For each graph node, derive `tau_hours = Dates.value(node.end_datetime - node.start_datetime) / 3_600_000` (milliseconds to hours). For single-block stages (this ticket), there is one block per stage, so `tau_k = tau_hours`.
2. **Compute zeta per node**: `zeta = 0.0036 * tau_hours` (the flow-to-volume conversion factor).
3. **Multiply all objective cost terms by tau**: The `add_system_objective!` function must prefix every cost term with `tau *`:
   - Thermal: `tau * cost * generation`
   - Deficit: `tau * deficit_cost * deficit`
   - Exchange: `tau * exchange_penalty * (direct + reverse)`
   - Spillage: `tau * spillage_penalty * spillage`
   - Hydro min gen slack: `tau * deficit_cost * 1.0001 * slack`
   - Non-controllable curtailment: `tau * curtailment_cost * curtailment`
   - Contract dispatch: `tau * price_per_mwh * dispatch`
4. **Apply zeta to water balance**: The `add_hydro_balance!` must multiply all flow terms by zeta:
   - `v_h.out == v_h.in + zeta * (INFLOW + upstream_outflow - OUTFLOW +/- pumping)`
5. **Pass tau and zeta into the subproblem builder closure**: `__generate_subproblem_builder` must look up the graph node for each `node::Integer` argument and compute tau and zeta. These values must be passed to `add_system_objective!` and `add_hydro_balance!`.
6. **Signature changes**:
   - `add_system_objective!(m, s, tau)` -- add `tau::Float64` parameter
   - `add_hydro_balance!(m, hydros, pump_source_map, pump_dest_map, zeta)` -- add `zeta::Float64` parameter
7. **No changes to variable symbols or new variables**: This ticket changes coefficients only.

### Inputs/Props

- `tau::Float64`: Stage duration in hours, computed from `(node.end_datetime - node.start_datetime)` in ms / 3_600_000.
- `zeta::Float64`: Time conversion factor = `0.0036 * tau`.
- Both are computed per-node inside `__generate_subproblem_builder`.

### Outputs/Behavior

- All simulation output values remain in the same physical units (MW for generation, m3/s for flows, hm3 for storage). Only cost-related outputs (STAGE_COST, FUTURE_COST, TOTAL_COST) change magnitude (they now represent actual dollars per stage, not dollars per unit time).
- Water balance is dimensionally consistent: LHS in hm3, RHS in hm3.

### Error Handling

- If `node.end_datetime <= node.start_datetime`, the existing graph validator already rejects this. No new error handling needed.
- If tau_hours is zero (zero-length stage), this should be logged as a warning but allowed (degenerate stage with no cost and no water balance change).

## Acceptance Criteria

1. Given a graph with monthly stages (e.g., 730 hours), when the model is built, then the objective coefficient for a thermal with cost 100 $/MWh is `730 * 100 = 73000` $/MW per stage (the cost of running 1 MW for the full stage).
2. Given a hydro with inflow = 100 m3/s and tau = 730 hours, when the model is built, then the zeta factor is `0.0036 * 730 = 2.628` and the water balance converts the inflow to `2.628 * 100 = 262.8` hm3.
3. Given the existing `example/1dtoy` case, when `read_study -> build -> train -> simulate` is executed, then the model solves without errors (costs are numerically larger but optimization still converges).
4. Given the scaling system (AutoScaling), when `compute_scaling_factors` is called, then it still produces valid scaling factors (no changes to scaling logic needed -- scaling divides parameters before tau multiplication, so the tau multiplier applies to already-scaled costs).
5. Given the `_get_variable_unscale_factor` function, when unscaling simulation results, then cost-related variables (STAGE_COST, FUTURE_COST, TOTAL_COST) are correctly unscaled (no change needed -- these are output by SDDP.jl directly, and scaling applies to coefficients, not to the tau multiplier).

## Implementation Guide

### Suggested Approach

**Step 1: Build a node-to-datetime lookup.**

In `__generate_subproblem_builder`, before the closure, build a `Dict{Int,Tuple{DateTime,DateTime}}` mapping `node.id => (node.start_datetime, node.end_datetime)` from the graph nodes. This allows the closure to look up the datetimes per node.

```julia
# In __generate_subproblem_builder, after getting scenarios/graph:
graph = get_graph(scenarios)
node_datetimes = Dict{Int,Tuple{DateTime,DateTime}}()
for n in graph.nodes
    node_datetimes[n.id] = (n.start_datetime, n.end_datetime)
end
```

**Step 2: Compute tau and zeta inside the closure.**

In `fun_sp_build(m, node)`, compute:

```julia
start_dt, end_dt = node_datetimes[node]
tau = Float64(Dates.value(end_dt - start_dt)) / 3_600_000.0
zeta = 0.0036 * tau
```

**Step 3: Pass tau to `add_system_objective!`.**

Change the signature to `add_system_objective!(m::JuMP.Model, s::SystemData, tau::Float64)` and multiply every cost term by `tau`:

```julia
SDDP.@stageobjective(
    m,
    tau * sum(thermals[n].cost * m[THERMAL_GENERATION][n] for n in 1:num_thermals) +
    tau * sum(buses[n].deficit_cost * m[DEFICIT][n] for n in 1:num_buses) +
    # ... etc
)
```

**Step 4: Pass zeta to `add_hydro_balance!`.**

Change the signature to `add_hydro_balance!(m, hydros, pump_source_map, pump_dest_map, zeta)` and multiply all flow contributions by `zeta`:

```julia
m[HYDRO_BALANCE] = JuMP.@constraint(
    m,
    [n = 1:num_hydros],
    m[STORED_VOLUME][n].out ==
        m[STORED_VOLUME][n].in +
        zeta * m[INFLOW][n] -
        zeta * m[OUTFLOW][n] +
        zeta * sum(m[OUTFLOW][j] for j in 1:num_hydros if downstream(...)) -
        zeta * sum(m[PUMPED_FLOW][j] for j in get(pump_source_map, n, Int[])) +
        zeta * sum(m[PUMPED_FLOW][j] for j in get(pump_dest_map, n, Int[]))
)
```

**Step 5: Add `using Dates` to the Engines module** if not already imported (needed for `Dates.value`). Check `src/Engines/Engines.jl` -- if Dates is not imported, add `using Dates` there.

**Step 6: Update tests.**

Create `test/test-stage-duration.jl` with unit tests that verify:

- tau computation from datetimes
- zeta computation
- Objective coefficients include tau
- Water balance includes zeta
- End-to-end build/train/simulate with the 1dtoy example

### Key Files to Modify

| File                          | Changes                                                                                                                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/Engines/sddp/build.jl`   | Modify `__generate_subproblem_builder` (add node_datetimes lookup, compute tau/zeta), `add_system_objective!` (add tau parameter, multiply all terms), `add_hydro_balance!` (add zeta parameter, multiply flow terms) |
| `src/Engines/Engines.jl`      | Add `using Dates` if not present                                                                                                                                                                                      |
| `test/test-stage-duration.jl` | New test file                                                                                                                                                                                                         |

### Patterns to Follow

- Follow the same closure-capture pattern used for `bus_ids`, `hydro_ids`, and bus maps in `__generate_subproblem_builder` (lines 396-428): precompute the lookup outside the closure, capture it, use it inside.
- The `SDDP.@stageobjective` macro call pattern is already established in `add_system_objective!` lines 241-254 -- just add `tau *` to each term.
- The `JuMP.@constraint` pattern for hydro balance is at lines 200-213 -- just add `zeta *` to each flow term.

### Pitfalls to Avoid

- **Do NOT change the scaling system** for this ticket. Scaling divides cost parameters (e.g., `t.cost / s_cost`) before they reach `add_system_objective!`. The tau multiplier operates on the already-scaled cost. This means the actual scaled objective coefficient is `tau * (cost / s_cost)`, which is correct because tau is a time constant, not a parameter magnitude. The scaling factors computed in `compute_scaling_factors` remain valid.
- **Do NOT factor zeta into the `SDDP.parameterize` callback.** The `JuMP.fix.(m[omega_INFLOW], omega)` call sets the noise term, which is in m3/s. The zeta factor applies in the water balance constraint, not in the parameterization.
- **Do NOT modify `_get_variable_unscale_factor`** for this ticket. The tau/zeta multipliers affect constraint coefficients, not variable scaling. SDDP.jl reports `stage_objective` (which already includes tau) and `bellman_term` (which is in $ regardless). The existing unscale factors for `STAGE_COST`, `FUTURE_COST`, `TOTAL_COST` (`s_cost * s_gen`) remain correct because they undo the parameter scaling, not the time scaling.
- **Import `Dates` at module level**, not inside a function. The `Dates.value` function is needed inside the closure.
- **Ensure `tau` is `Float64`**, not an integer division result. `Dates.value` returns `Int64` (milliseconds), so divide by `3_600_000.0` (note the `.0`) to get Float64.

## Testing Requirements

### Test Protocol

- **ALWAYS** use `TEST_FILTER="test-stage-duration"` with 120000ms Bash timeout for unit tests
- **NEVER** run `test-main` without 360000ms timeout
- Create a NEW test file `test/test-stage-duration.jl` (do not add to existing files)
- Use HiGHS for any solver-dependent tests

### Unit Tests

Create `test/test-stage-duration.jl`:

1. **tau computation**: Given two DateTimes 730 hours apart, verify tau = 730.0.
2. **zeta computation**: Given tau = 730, verify zeta = 0.0036 \* 730 = 2.628.
3. **Objective includes tau**: Build a minimal model with one thermal (cost=100), verify the objective coefficient equals `tau * 100`.
4. **Water balance includes zeta**: Build a minimal hydro model, verify the hydro balance constraint coefficients include the zeta factor.
5. **Zero-duration stage**: Given start_datetime == end_datetime, verify tau = 0, zeta = 0, and no crash.

### Integration Tests

6. **End-to-end with 1dtoy**: Load the example case, build, train (3 iterations), simulate (1 replication), verify no errors. Do NOT check specific numerical values (costs will differ from pre-tau).

### E2E Tests

Not applicable -- the integration test above covers the pipeline.

## Dependencies

- **Blocked By**: ticket-027 (Epic 05 complete)
- **Blocks**: ticket-029, ticket-030

## Effort Estimate

**Points**: 3
**Confidence**: High
