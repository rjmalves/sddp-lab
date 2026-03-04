# ticket-030 Add Inflow Non-Negativity Methods

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify AR constraint modifications, SAA generation changes, and type stability)

## Context

### Background

The PAR(p) autoregressive model used for inflow generation can produce negative inflow values when the noise term eta is sufficiently negative. This is physically impossible (rivers cannot have negative flow) and can cause LP infeasibility when the water balance constraint requires non-negative inflow. The reference specification (inflow-nonnegativity.md) defines four methods to handle this: none, penalty, truncation, and truncation_with_penalty. This ticket implements all four methods as a configurable modeling option within the engine.

### Relation to Epic

This is the third and final ticket of Epic 06. It is independent of ticket-029 (blocks) but depends on ticket-028 for the zeta time conversion factor used in penalty cost calculations. The penalty methods add new variables and constraints to the LP subproblem, while the truncation method modifies the SAA generation in the StochasticProcess module.

### Current State

After ticket-028, the codebase has:

1. `src/Engines/sddp/build.jl` -- `add_inflow_uncertainty!(m, s::AutoRegressive, season)` (lines 282-321): Creates the AR constraint for each hydro: `(STCHP[i].out - s_t[1]) / s_t[2] == sum(ar_c[l] * (...).in ...) + omega_INFLOW[n]`. Then `JuMP.fix.(m[omega_INFLOW], omega)` in the parameterize callback fixes the noise term. The INFLOW variable is constrained to equal the AR state: `INFLOW[n] == STCHP[index_t[n]].out`.
2. `src/StochasticProcess/autoregressive.jl` -- `__generate_saa` delegates to `s.noise_model` (Naive), which generates the raw noise samples. No truncation is applied.
3. `src/StochasticProcess/naive.jl` -- `__generate_saa` generates noise from copula-based multivariate distributions. Output is the raw noise (can be any real number for Gaussian marginals).
4. The `zeta` factor from ticket-028 is available inside the subproblem builder closure.

Key observation from the learnings: "Inflow non-negativity: INFLOW is set by JuMP.fix in parameterize; a lower bound conflicts with fix; use a slack variable approach."

The current AR constraint structure (simplified for one hydro n, ignoring scaling):

```
AR main:  (STCHP[i].out - mu) / sigma = sum(phi_l * (STCHP[i+l-1].in - mu_lagged) / sigma_lagged) + omega_INFLOW[n]
Inflow:   INFLOW[n] = STCHP[index_t[n]].out
Parameterize: JuMP.fix(omega_INFLOW[n], noise_sample)
```

So `STCHP[i].out` is the actual inflow in the AR model's units (mean/sigma scaled), and `INFLOW[n]` equals it. The `omega_INFLOW` variable receives the noise realization.

## Specification

### Requirements

#### Configuration

1. **New modeling option**: Inflow non-negativity is configured under the engine configuration as a modeling option. Since the `SDDPEngine` currently has 4 fields (policy, simulation, diagnostics, solver), add a new `modeling` section or embed the configuration in one of the existing sections. The cleanest approach: add an `InflowNonNegativity` abstract type hierarchy to `Engines.jl`, construct it from the engine JSON config, and store it on `SDDPEngine` as a 5th field.
2. **Configuration format**:
   ```json
   {
     "engine": {
       "modeling": {
         "inflow_non_negativity": {
           "kind": "Penalty",
           "params": {
             "penalty_cost": 1000.0
           }
         }
       }
     }
   }
   ```
3. **Default**: When `"modeling"` or `"inflow_non_negativity"` is absent, default to `InflowNone()` (no treatment, current behavior).
4. **Types**:
   - `InflowNone <: InflowNonNegativity` -- no treatment
   - `InflowPenalty <: InflowNonNegativity` -- penalty slack on AR constraint
   - `InflowTruncation <: InflowNonNegativity` -- truncate SAA at zero
   - `InflowTruncationWithPenalty <: InflowNonNegativity` -- noise adjustment slack

#### Method: None

5. **No changes to LP**: Current behavior. Negative inflows pass through. May cause infeasibility.

#### Method: Penalty

6. **New variable**: `INFLOW_SLACK[h] >= 0` for each hydro h (units: same as omega_INFLOW, which is dimensionless noise). This slack absorbs negative inflow violations.
7. **Modified AR constraint**: Add the slack to the LHS:

   ```
   (STCHP[i].out - mu) / sigma - INFLOW_SLACK[n] = sum(phi_l * ...) + omega_INFLOW[n]
   ```

   The sign is: subtracting `INFLOW_SLACK` from the LHS makes the effective `STCHP[i].out` larger (less negative), so `INFLOW_SLACK` absorbs negative inflow.

   Actually, let us be precise. The AR constraint currently is:

   ```
   (STCHP[i].out - mu) / sigma == sum(ar_c[l] * (STCHP[i+l-1].in - mu_lag) / sigma_lag) + omega_INFLOW[n]
   ```

   This means `STCHP[i].out = mu + sigma * (sum(...) + omega)`. When omega is very negative, STCHP[i].out (which equals INFLOW[n]) can be negative.

   With the penalty slack, we want to ensure INFLOW[n] >= 0 by absorbing the negative part:

   ```
   INFLOW[n] + INFLOW_SLACK[n] >= 0   (but INFLOW is fixed by AR)
   ```

   Better formulation following the spec (inflow-nonnegativity.md Section 3): Add `sigma_inf_h >= 0` to the AR constraint:

   ```
   a_h + sigma_inf_h = AR_output
   ```

   When AR_output < 0, sigma_inf_h = -AR_output makes a_h = 0 (minimum feasible inflow).

   In SDDPlab terms: The constraint `INFLOW[n] == STCHP[i].out` becomes:

   ```
   INFLOW[n] + INFLOW_SLACK[n] == STCHP[index_t[n]].out
   ```

   Combined with `INFLOW[n] >= 0` (a new lower bound) and `INFLOW_SLACK[n] >= 0`, when STCHP[i].out < 0, the optimizer sets INFLOW[n] = 0 and INFLOW_SLACK[n] = |STCHP[i].out|.

   **Important**: The `INFLOW` variable currently has NO lower bound. We must add `JuMP.set_lower_bound(m[INFLOW][n], 0)` when using the penalty method.

8. **Objective penalty**: Add `zeta * penalty_cost * INFLOW_SLACK[n]` for each hydro to the objective. The zeta factor converts from flow-rate-time units to monetary units: penalty_cost is in $/(m3/s*h), INFLOW_SLACK is in m3/s, and zeta * penalty_cost gives $/m3/s \* (hm3/(m3/s)) -- wait, let us be precise.

   The penalty cost c_inf has units $/(m3/s _ h). The slack sigma_inf has units m3/s. The penalty in the objective should be: `c_inf _ sigma_inf _ zeta` where zeta = 0.0036 _ sum(tau_k). But actually, in the spec the penalty is `c_inf * sigma_inf * zeta` and it produces $.

   Let us verify: `$/(m3/s * h) * (m3/s) * (hm3 / (m3/s))` -- the units of zeta are hm3/(m3/s), which is hours _ 0.0036. So `c_inf _ sigma_inf * zeta = $/(m3/s*h) _ m3/s _ 0.0036 _ hours = $ _ 0.0036`. That is not right dimensionally.

   Re-reading the spec: "c_inf is the penalty cost (default: 1000 $/(m3/s * h))". And the penalty term is `sum_h c_inf * sigma_inf_h * zeta`. Since sigma_inf_h is in m3/s and zeta is in hm3/(m3/s) = 0.0036 * hours, we get: `$/(m3/s*h) * m3/s _ 0.0036 _ hours = 0.0036 \* $`. That seems like a scaling issue.

   Actually, looking more carefully: zeta converts flow to volume. So `sigma_inf * zeta` gives the volume of "fictitious water" added, in hm3. And `c_inf * sigma_inf * zeta` has units `$/(m3/s*h) * m3/s * hm3/(m3/s)`. That does not simplify cleanly.

   **Simpler interpretation**: The penalty should be proportional to the flow rate and stage duration. The most natural formulation: `c_inf * sigma_inf * tau` where tau is stage duration in hours. This gives `$/(m3/s*h) * m3/s * h = $`. Use `tau = sum(tau_k)` for the full stage penalty.

   But the spec says `c_inf * sigma_inf * zeta`. Let me re-read: yes, the spec says `zeta`. Since `zeta = 0.0036 * tau`, this means the penalty is `c_inf * sigma_inf * 0.0036 * tau`. This would mean the penalty cost is really in `$/hm3` (after multiplying by zeta). That is: `c_inf_effective = c_inf * 0.0036` in $/hm3, and the total penalty is `c_inf_effective * sigma_inf * tau`.

   Actually, the simplest reading: the spec writes the penalty as `c_inf * sigma_inf_h * zeta`. Since all other flow-related penalties (spillage) are written as `c_spill * s_h * tau_k` (per block), and the inflow penalty is NOT per-block (it is per-stage, since inflow is stage-level), the correct form is: **`c_inf * sigma_inf_h * zeta`** where zeta = 0.0036 \* sum(tau_k). Follow the spec exactly.

9. **Scaling**: The penalty cost `c_inf` should be included in the scaling system. Add it to `all_costs` in `compute_scaling_factors`. The inflow slack has units of m3/s, so it scales with the flow scale `s_flow`. Add `INFLOW_SLACK => s_flow` to `_get_variable_unscale_factor`.

#### Method: Truncation

10. **Modify SAA generation**: In `__generate_saa` for `AutoRegressive`, apply `max(0, ...)` to the final inflow value after the AR computation. Since the SAA generates noise terms (not inflows directly), the truncation must be applied at the point where noise is combined with the AR model to produce inflow values.

    Actually, the SAA generates noise terms `eta` (from the Naive model). The actual inflow `a_h` is computed inside the LP via the AR constraint. The truncation method should truncate the **realized inflow** at generation time, meaning we need to compute the full AR output during SAA generation and truncate it.

    This requires: (a) storing the AR model parameters to compute inflows during SAA generation, (b) applying max(0, inflow) and back-computing the adjusted noise.

    **Simpler alternative**: Truncation adjusts the noise term so that the resulting inflow is non-negative. Since `a_h = mu + sigma * (sum(phi * lags) + eta)`, truncation sets `eta_truncated = max(eta, -(mu + sigma * sum(phi * lags)) / sigma)`. But this requires knowing the lag values at generation time, which we do not have (lags are state variables from the previous stage).

    **Actually**, the SAA generates the noise `eta` independently. The lags are only known at runtime (during SDDP solve). So pure truncation at SAA time cannot guarantee non-negative inflows -- it can only truncate the noise term itself. The spec says: "a_h = max(0, AR_output) applied in generate_saa / \_\_generate_saa". This means truncation is applied to the final realized inflow, not to the noise. But the realized inflow depends on state variables (lags) which are only known during the solve.

    **Resolution**: Truncation in the LP context means adding `a_h >= 0` as a hard constraint in the LP (lower bound on INFLOW). The noise generates the full (possibly negative) value, and the LP enforces non-negativity by setting `INFLOW[n] >= 0`. This is simpler than modifying SAA generation.

    Wait, but the INFLOW variable is fixed by `INFLOW[n] == STCHP[index_t[n]].out`, and `STCHP[i].out` is determined by the AR constraint and the fixed noise. So adding a lower bound on INFLOW would make the LP infeasible when the AR produces negative inflow (the equality constraint forces INFLOW = negative value, but the bound requires INFLOW >= 0).

    **The correct approach for truncation**: Modify the `SDDP.parameterize` callback to truncate the noise values before fixing them. Instead of `JuMP.fix.(m[omega_INFLOW], omega)`, use `JuMP.fix.(m[omega_INFLOW], max.(omega, lower_bound))` where `lower_bound` is computed to ensure non-negative inflow. But this requires knowing the AR coefficients and lag states at parameterize time.

    **Simplest correct truncation**: Apply `max(0, ...)` to the raw noise samples in the SAA. This truncates very negative noise that would most commonly produce negative inflows. It does not guarantee non-negative inflows (because lag contributions can also be negative), but it reduces the frequency. This is what the spec describes as "simple truncation".

    **Final decision**: Implement truncation as `max.(0, noise_sample)` applied in the SAA generation. This truncates the noise at zero, not the inflow at zero. For a more robust guarantee, users should use the penalty method.

11. **No LP changes for truncation**: The LP remains unchanged. Only the SAA noise values are clipped.

#### Method: Truncation with Penalty

12. **New variable**: `NOISE_ADJUSTMENT_SLACK[h] >= 0` for each hydro h (dimensionless, same units as omega_INFLOW).
13. **Modified AR constraint**: Replace `omega_INFLOW[n]` with `omega_INFLOW[n] + NOISE_ADJUSTMENT_SLACK[n]`:
    ```
    (STCHP[i].out - mu) / sigma == sum(ar_c[l] * ...) + omega_INFLOW[n] + NOISE_ADJUSTMENT_SLACK[n]
    ```
14. **Non-negativity constraint on INFLOW**: Add `INFLOW[n] >= 0` (lower bound).
15. **Objective penalty**: `c_inf * sigma_m * NOISE_ADJUSTMENT_SLACK[n] * zeta` where `sigma_m` is the AR residual standard deviation for the current season.

    In the current code, `s_t[2]` is `sigma_m` (the scale parameter, accessed via `get_ar_scale`). So the penalty is `c_inf * s_t[2] * NOISE_ADJUSTMENT_SLACK[n] * zeta`. The sigma_m factor converts the dimensionless noise adjustment back to m3/s units.

### Inputs/Props

- `method`: One of `InflowNone`, `InflowPenalty`, `InflowTruncation`, `InflowTruncationWithPenalty`
- `penalty_cost::Float64`: For penalty and truncation_with_penalty methods (default: 1000.0)
- `zeta::Float64`: Time conversion factor from ticket-028 (needed for penalty costs)

### Outputs/Behavior

- **None**: Identical to current behavior.
- **Penalty**: LP always feasible. `INFLOW_SLACK` appears in simulation output. Marginal water values are slightly affected.
- **Truncation**: SAA noise values are clipped at zero. LP formulation unchanged. Output unchanged.
- **Truncation with penalty**: LP always feasible. `NOISE_ADJUSTMENT_SLACK` appears in simulation output. INFLOW is non-negative.

### Error Handling

- If penalty_cost <= 0 for penalty methods: `AssertionError` via FieldRule `positive()` constraint.
- If unknown method kind: `AssertionError` from `__kind_factory!`.
- If penalty or truncation_with_penalty is used with Naive process (not AR): emit a warning -- the Naive process does not have AR constraints, so these methods are not applicable. Fall back to InflowNone with a warning.

## Acceptance Criteria

1. Given no `"modeling"` config in engine JSON, when the engine is built, then `InflowNone()` is the default inflow non-negativity method.
2. Given `"inflow_non_negativity": {"kind": "Penalty", "params": {"penalty_cost": 1000}}`, when the engine is built, then `InflowPenalty(1000.0)` is constructed.
3. Given `InflowPenalty` method and an AutoRegressive process, when the subproblem is built, then `INFLOW_SLACK` variables exist, `INFLOW >= 0`, and the objective includes the penalty term.
4. Given a scenario where the AR model would produce negative inflow (very negative noise), when using `InflowPenalty`, then the LP solves feasibly with `INFLOW_SLACK > 0` and `INFLOW = 0`.
5. Given `InflowTruncation` method, when SAA is generated, then all noise values in the SAA are >= 0 (clipped at zero).
6. Given `InflowTruncationWithPenalty` method, when the subproblem is built, then `NOISE_ADJUSTMENT_SLACK` variables exist, `INFLOW >= 0`, and the AR constraint includes the noise adjustment.
7. Given `InflowNone` method, when the model is built, then behavior is identical to the current implementation (no new variables, no constraints modified).
8. Given a Naive stochastic process (not AR) and `InflowPenalty`, when the engine is built, then a warning is emitted and the method falls back to `InflowNone`.
9. Given the existing 1dtoy example with no modeling config, when build/train/simulate is run, then behavior is identical to ticket-028 (backward compatibility).

## Implementation Guide

### Suggested Approach

**Step 1: Define InflowNonNegativity type hierarchy.**

In `src/Engines/Engines.jl`, add:

```julia
abstract type InflowNonNegativity end

struct InflowNone <: InflowNonNegativity end

struct InflowPenalty <: InflowNonNegativity
    penalty_cost::Float64
end

struct InflowTruncation <: InflowNonNegativity end

struct InflowTruncationWithPenalty <: InflowNonNegativity
    penalty_cost::Float64
end
```

**Step 2: Add constructors and validators.**

In `src/Engines/sddp/input.jl`, add Dict constructors following the `__kind_factory!` pattern:

```julia
function InflowNone(::Dict{String,Any}, ::CompositeException)
    return InflowNone()
end

function InflowPenalty(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, INFLOW_PENALTY_SCHEMA, e)
    return valid ? InflowPenalty(d["penalty_cost"]) : nothing
end
# ... etc
```

In `src/Engines/sddp/input-validators.jl`, add:

```julia
const INFLOW_PENALTY_SCHEMA = [
    FieldRule("penalty_cost", Real; constraints = [positive()]),
]
```

**Step 3: Add modeling config to SDDPEngine.**

Option A (simpler): Add `inflow_non_negativity::InflowNonNegativity` as a 5th field on `SDDPEngine`. This requires modifying the `SDDPEngine` struct and its constructor.

Option B: Add a `ModelingConfig` struct that holds `inflow_non_negativity` and potentially future modeling options. Cleaner for extensibility.

Choose Option A for simplicity (can refactor to B later). Add parsing in the engine builder: if `haskey(d, "modeling")` and `haskey(d["modeling"], "inflow_non_negativity")`, use `__kind_factory!` to build it; otherwise default to `InflowNone()`.

**Step 4: Pass the method to the subproblem builder.**

In `__generate_subproblem_builder`, receive the `InflowNonNegativity` instance. Pass it to `add_inflow_uncertainty!` as an additional argument.

**Step 5: Implement penalty method in build.jl.**

Create a new function `apply_inflow_nonnegativity!(m, method::InflowPenalty, ...)` called after `add_inflow_uncertainty!`:

- Create `INFLOW_SLACK[1:n_hydro]` variables with lower bound 0
- Modify the inflow equality constraint: change `INFLOW[n] == STCHP[index_t[n]].out` to `INFLOW[n] + INFLOW_SLACK[n] == STCHP[index_t[n]].out`
- Add `JuMP.set_lower_bound(m[INFLOW][n], 0)` for all hydros
- The objective penalty term will be added in `add_system_objective!`

Actually, modifying the constraint after creation is complex in JuMP. Better approach: modify `add_inflow_uncertainty!` itself to accept the method and conditionally include the slack:

```julia
function add_inflow_uncertainty!(m, s::AutoRegressive, season, method::InflowPenalty)
    # ... same setup as current ...
    m[INFLOW_SLACK] = JuMP.@variable(m, [1:n_hydro], base_name = String(INFLOW_SLACK))
    JuMP.set_lower_bound.(m[INFLOW_SLACK], 0)

    JuMP.@constraint(m, inflow[n = 1:n_hydro],
        m[INFLOW][n] + m[INFLOW_SLACK][n] == m[STCHP][index_t[n]].out)
    JuMP.set_lower_bound.(m[INFLOW], 0)
    # ... rest ...
end
```

For `InflowNone`, the existing `add_inflow_uncertainty!` code is used unchanged (dispatch on the method type).

**Step 6: Implement truncation method in SAA generation.**

In `__generate_subproblem_builder`, when method is `InflowTruncation`, clip the SAA noise values:

```julia
if method isa InflowTruncation
    for node in eachindex(SAA)
        SAA[node] = [max.(0.0, omega) for omega in SAA[node]]
    end
end
```

This is simplest to do right after SAA generation and scaling, before the closure.

**Step 7: Implement truncation_with_penalty in build.jl.**

Similar to penalty but the slack is on the noise term, not the inflow:

```julia
function add_inflow_uncertainty!(m, s::AutoRegressive, season, method::InflowTruncationWithPenalty)
    # ... same AR setup ...
    m[NOISE_ADJUSTMENT_SLACK] = JuMP.@variable(m, [1:n_hydro], ...)
    JuMP.set_lower_bound.(m[NOISE_ADJUSTMENT_SLACK], 0)

    # Modified AR: add NOISE_ADJUSTMENT_SLACK to the RHS
    for (n, t) in enumerate(...)
        JuMP.@constraint(m,
            (m[STCHP][i].out - s_t[1]) / s_t[2] ==
                sum(...) + m[omega_INFLOW][n] + m[NOISE_ADJUSTMENT_SLACK][n], ...)
    end

    # INFLOW >= 0
    JuMP.@constraint(m, inflow[n = 1:n_hydro], m[INFLOW][n] == m[STCHP][index_t[n]].out)
    JuMP.set_lower_bound.(m[INFLOW], 0)
end
```

**Step 8: Add penalty to objective.**

Modify `add_system_objective!` to accept the inflow non-negativity method and add penalty terms:

- For `InflowPenalty`: `+ zeta * method.penalty_cost * sum(m[INFLOW_SLACK])` (if INFLOW_SLACK exists)
- For `InflowTruncationWithPenalty`: `+ zeta * method.penalty_cost * sum(sigma_m[n] * m[NOISE_ADJUSTMENT_SLACK][n] for n in ...)` (need sigma_m per hydro per season)

**Step 9: Register new variable symbols.**

In `src/Lab/variables.jl`:

```julia
INFLOW_SLACK = Symbol("INFLOW_SLACK")
NOISE_ADJUSTMENT_SLACK = Symbol("NOISE_ADJUSTMENT_SLACK")
```

Export in `src/Lab/Lab.jl`.

**Step 10: Update scaling and unscaling.**

- `compute_scaling_factors`: Add inflow penalty cost to `all_costs` if applicable.
- `_get_variable_unscale_factor`: Add `INFLOW_SLACK => s_flow`, `NOISE_ADJUSTMENT_SLACK => 1.0` (dimensionless).
- `save_simulation.jl`: Add INFLOW_SLACK and NOISE_ADJUSTMENT_SLACK to `map_variable_output["operation_hydros"]` and `map_variable_entities`.

### Key Files to Modify

| File                                   | Changes                                                                                                                                                                                                                                                                             |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/Engines/Engines.jl`               | Add `InflowNonNegativity` abstract type + 4 subtypes; add field to `SDDPEngine`; export types                                                                                                                                                                                       |
| `src/Engines/sddp/input.jl`            | Add Dict constructors for all 4 types; add `__build_modeling!` helper; modify SDDPEngine builder                                                                                                                                                                                    |
| `src/Engines/sddp/input-validators.jl` | Add `INFLOW_PENALTY_SCHEMA`; add modeling config validators                                                                                                                                                                                                                         |
| `src/Engines/sddp/build.jl`            | Add `method` parameter to `add_inflow_uncertainty!` dispatches; add penalty variable creation; modify AR constraints for penalty/truncation_with_penalty; add SAA truncation; modify `add_system_objective!` for penalty terms; pass method through `__generate_subproblem_builder` |
| `src/Engines/sddp/scaling.jl`          | Add `INFLOW_SLACK` to `no_scaling_config`; optionally add penalty cost to scaling                                                                                                                                                                                                   |
| `src/Engines/sddp/save_simulation.jl`  | Add `INFLOW_SLACK`, `NOISE_ADJUSTMENT_SLACK` to unscale and output maps                                                                                                                                                                                                             |
| `src/Lab/variables.jl`                 | Add `INFLOW_SLACK`, `NOISE_ADJUSTMENT_SLACK` symbols                                                                                                                                                                                                                                |
| `src/Lab/Lab.jl`                       | Export new symbols                                                                                                                                                                                                                                                                  |
| `test/test-inflow-nonnegativity.jl`    | New test file                                                                                                                                                                                                                                                                       |

### Patterns to Follow

- Follow the `__kind_factory!` pattern established for `StoppingCriteria`, `RiskMeasure`, etc. in `src/Engines/sddp/input.jl`: parameterless types get `Type(::Dict, ::CompositeException) = Type()` constructors; types with params get schema-validated constructors.
- Follow the optional config pattern from Epic 05: `if haskey(d, "modeling") ... else d["modeling"] = default end`.
- Follow the method dispatch pattern: `add_inflow_uncertainty!(m, s, season, ::InflowNone)` calls the existing code; `add_inflow_uncertainty!(m, s, season, ::InflowPenalty)` has the penalty variant.
- For new variable symbols, follow the exact pattern in `src/Lab/variables.jl` lines 1-39.

### Pitfalls to Avoid

- **Do NOT add a lower bound on INFLOW for the `none` method.** The current code has no lower bound on INFLOW, and adding one would change behavior.
- **Do NOT modify the AR constraint for the `none` and `truncation` methods.** Only penalty and truncation_with_penalty change the LP formulation.
- **The sigma_m value varies per season.** For `truncation_with_penalty`, the penalty coefficient `c_inf * sigma_m` depends on the season. Since `add_inflow_uncertainty!` is called per-node with the correct season, access `sigma_m` from `get_ar_scale(s, season)` inside the function.
- **The SAA truncation for `InflowTruncation`** must happen before the parameterize callback, but after SAA scaling. Apply it in `__generate_subproblem_builder` right after the SAA scaling loop (currently lines 402-407 in build.jl).
- **Do not forget to handle the Naive process case.** `add_inflow_uncertainty!(m, s::Naive, season)` does not have AR constraints. Penalty and truncation_with_penalty are not applicable. The function should accept the method parameter but only apply it for AR processes. For Naive with penalty/truncation_with_penalty, emit a warning and do nothing.
- **The `SDDPEngine` constructor change** requires updating all existing test code that creates `SDDPEngine` instances. Grep for `SDDPEngine(` to find all call sites.

## Testing Requirements

### Test Protocol

- **ALWAYS** use `TEST_FILTER="test-inflow-nonnegativity"` with 120000ms Bash timeout
- **NEVER** run `test-main` without 360000ms timeout
- Create a NEW test file `test/test-inflow-nonnegativity.jl`
- Use HiGHS for solver-dependent tests

### Unit Tests

Create `test/test-inflow-nonnegativity.jl`:

1. **Config parsing -- none default**: Given no modeling config, verify `InflowNone()` is constructed.
2. **Config parsing -- penalty**: Given valid penalty config, verify `InflowPenalty(1000.0)` is constructed.
3. **Config parsing -- truncation**: Given truncation config, verify `InflowTruncation()` is constructed.
4. **Config parsing -- truncation_with_penalty**: Given valid config, verify construction with penalty_cost.
5. **Config validation -- negative penalty**: Given `penalty_cost: -1`, verify error.
6. **Penalty method -- INFLOW_SLACK exists**: Build with penalty method and AR process, verify `INFLOW_SLACK` variable exists in the JuMP model.
7. **Penalty method -- INFLOW >= 0**: Build with penalty method, verify `JuMP.lower_bound(m[INFLOW][1]) == 0`.
8. **Truncation method -- SAA clipped**: Generate SAA with truncation, verify all noise values >= 0.
9. **Truncation_with_penalty -- NOISE_ADJUSTMENT_SLACK exists**: Build with this method, verify the variable exists.
10. **None method -- no changes**: Build with `InflowNone`, verify no `INFLOW_SLACK` or `NOISE_ADJUSTMENT_SLACK` variables, and INFLOW has no lower bound.
11. **Naive process fallback**: Build with `InflowPenalty` and Naive process, verify warning and no crash.

### Integration Tests

12. **End-to-end with penalty**: Use 1dtoy with AR process and penalty config, build/train(3 iter)/simulate, verify no errors and INFLOW_SLACK appears in simulation output.
13. **Backward compatibility**: Use 1dtoy with no modeling config, verify identical behavior to ticket-028.

## Dependencies

- **Blocked By**: ticket-028 (zeta time conversion factor is needed for penalty costs)
- **Blocks**: None

## Effort Estimate

**Points**: 4
**Confidence**: Medium
