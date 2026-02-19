# ticket-030 Add Inflow Non-Negativity Methods

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify AR constraint modifications, SAA generation changes, and type stability)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add configurable methods for preventing negative inflow realizations from the PAR(p)/AutoRegressive model. The current SDDPlab does not treat negative inflows, which can cause LP infeasibility. This ticket implements four methods:

### Method 1: None (`none`)

No treatment. Negative inflows pass directly to the LP. May cause infeasibility. Useful only for debugging.

### Method 2: Penalty (`penalty`) -- RECOMMENDED

Add a slack variable `sigma_inf_h >= 0` to the AR constraint to absorb negative inflow violations.

- **Modified AR constraint**: `a_h + sigma_inf_h = AR_output`
- **Objective addition**: `+ sum_h c_inf * sigma_inf_h * zeta`
- where `c_inf` is the penalty cost (default: 1000 $/(m3/s\*h)) and `zeta` is the time conversion factor
- LP is always feasible; clear cost signal for negative inflow events

### Method 3: Truncation (`truncation`)

Hard truncation of negative values to zero during SAA scenario generation.

- `a_h = max(0, AR_output)` applied in `generate_saa` / `__generate_saa`
- Simple, no additional LP variables
- Biases distribution upward, breaks AR temporal correlation when truncation occurs

### Method 4: Truncation with Penalty (`truncation_with_penalty`)

Hybrid approach: adjust the noise term via a penalized slack, keeping the AR structure intact.

- **Additional variable**: `xi_h >= 0` (noise adjustment slack, dimensionless)
- **Modified noise**: `eta_adj = eta + xi_h`
- **Modified AR**: `a_h = deterministic_base + sum_l psi_l * a_{h,l} + sigma_m * eta_adj`
- **Non-negativity**: `a_h >= 0`
- **Objective**: `+ sum_h c_inf * sigma_m * xi_h * zeta`
- Based on the YP_FINF approach in SPARHTACUS/SPTcpp

### Configuration

```json
{
  "modeling": {
    "inflow_non_negativity": {
      "method": "penalty",
      "penalty_cost": 1000.0
    }
  }
}
```

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (modify `add_inflow_uncertainty!` for AR process to add slack variables and modified constraints), `src/StochasticProcess/autoregressive.jl` (truncation in `__generate_saa` for truncation method), `src/StochasticProcess/naive.jl` (truncation in `__generate_saa` for Naive process if applicable), `src/Engines/Engines.jl` (new `InflowNonNegativity` abstract type with subtypes), `src/Engines/sddp/input.jl` (parse config, generate method), `src/Engines/sddp/input-validators.jl` (validate config), `src/Lab/variables.jl` (new symbols: `INFLOW_SLACK`, `NOISE_ADJUSTMENT_SLACK`)
- **Key decisions needed**:
  - Whether inflow non-negativity is a modeling config (under `engine.modeling`) or a scenario config (under `scenarios`)
  - How the penalty method's `sigma_inf_h` interacts with the existing `add_inflow_uncertainty!` function signature
  - Whether the Naive process also needs non-negativity treatment (it uses copula-based sampling which could also produce negative values)
  - How `zeta` from ticket-028 feeds into the penalty term (if ticket-028 is not yet implemented, use a placeholder or deferred multiplication)
  - Whether the truncation method modifies the SAA at generation time or at parameterize time
- **Open questions**:
  - Should `penalty_cost` have a default value if not specified? (POWE.RS uses 1000 $/(m3/s\*h))
  - Should the inflow slack variables be included in simulation output?
  - How does the penalty method interact with the scaling system? (Penalty costs might have different magnitude than generation costs)
  - Is the truncation_with_penalty method needed in the first implementation, or can it be deferred?

## Dependencies

- **Blocked By**: ticket-028 (zeta time conversion factor is needed for penalty costs; but can proceed with deferred zeta if needed)
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
