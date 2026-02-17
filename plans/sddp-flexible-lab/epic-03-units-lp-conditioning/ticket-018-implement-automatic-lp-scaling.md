# ticket-018 Implement Automatic LP Coefficient Scaling

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify JuMP model transformation performance and type stability)

## Context

### Background

In hydrothermal dispatch SDDP models, LP coefficients can span many orders of magnitude. For example, a hydro plant might have storage bounds in the tens of thousands of hm3, generation costs in dollars per MWh (single digits), and productivity coefficients that convert flow (hm3/period) to power (MW). When these coefficients appear in the same constraint matrix, solvers may struggle with numerical precision, leading to incorrect dual values and poor cuts.

SDDP.jl does NOT provide a built-in scaling mechanism, and applying post-hoc LP matrix scaling is problematic because SDDP's cut generation relies on dual values from the unscaled problem. The practical approach is **input-data rescaling**: applying known conversion factors to input parameters BEFORE building the JuMP model, so that the resulting LP coefficients are in a numerically well-conditioned range (typically within 3-4 orders of magnitude of each other). This is a preprocessing step on the `SystemData` (and/or `ScenariosData`), not a JuMP-level transformation.

### Relation to Epic

This is the second ticket in Epic 03. It builds on the units registry from ticket-017 to define sensible scaling factors, and applies them to normalize input data before model construction. The diagnostics ticket (ticket-019) will then be able to verify that scaling has improved coefficient conditioning.

### Current State

- `src/Engines/sddp/build.jl` uses raw entity field values directly when creating variables and constraints. For example, `ses.entities[n].max_generation` is used directly as an upper bound, `ses.entities[n].cost` is used directly as an objective coefficient.
- The `add_system_elements!` functions in `build.jl` directly access entity properties to set bounds and coefficients.
- The `add_system_objective!` function multiplies costs by generation variables, creating coefficients that are products of raw input values.
- The hydro balance constraint mixes stored volume (hm3) with inflow (hm3) and outflow (hm3), which are consistent in units but can vary wildly in magnitude across different systems.
- No scaling or normalization is applied anywhere in the pipeline.
- ticket-017 will have established a `VARIABLE_UNITS_REGISTRY` with expected magnitude ranges for each variable.

## Specification

### Requirements

1. **Create `src/Engines/sddp/scaling.jl`** with:
   - A `ScalingConfig` struct that holds per-variable scaling factors as a `Dict{Symbol, Float64}`. A scaling factor `s` means that the variable's values are divided by `s` before being used in the model (i.e., the model works with `x_scaled = x_original / s`).
   - A `DefaultScaling` singleton struct for no scaling (all factors = 1.0).
   - A function `compute_scaling_factors(system::SystemData)::ScalingConfig` that analyzes the system data to compute reasonable scaling factors based on the actual data ranges:
     - For storage variables: scale by `max(max_storage across all hydros)` so the scaled variable is in [0, 1].
     - For generation variables (hydro and thermal): scale by `max(max_generation across all plants)`.
     - For flow variables: scale by `max(max_generation / productivity across all hydros)`.
     - For deficit: scale by `max(load values)` or by `max(max_generation)`.
     - For cost coefficients: scale by `max(cost across all thermals, deficit_cost across all buses)`.
   - A function `apply_scaling(system::SystemData, config::ScalingConfig)::Tuple{SystemData, ScalingConfig}` that returns a new `SystemData` with scaled parameters and the effective scaling config for unscaling results later.

2. **Add `ScalingMode` abstract type** to `src/Engines/Engines.jl`:
   - `abstract type ScalingMode end`
   - `struct NoScaling <: ScalingMode end` -- pass-through, no scaling applied.
   - `struct AutoScaling <: ScalingMode end` -- compute and apply automatic scaling.
   - These follow the established `kind_factory!` pattern for JSONC configuration.

3. **Add `scaling` field to `SDDPPolicyTaskDefinition`**:
   - Optional field, defaults to `NoScaling()` when absent (backward compatible).
   - JSONC: `"scaling": {"kind": "AutoScaling", "params": {}}` or `"scaling": {"kind": "NoScaling", "params": {}}`.

4. **Integrate scaling into the build pipeline**:
   - In `src/Engines/sddp/build.jl`, the `Lab.build` function should check the scaling mode. If `AutoScaling`, compute scaling factors from the system data, apply them, and use the scaled system data for model building.
   - Store the `ScalingConfig` in the `SDDPModel` so that simulation results can be unscaled later.

5. **Add result unscaling**:
   - When simulation results are produced, the scaled variable values need to be multiplied back by their scaling factors before output. Modify `save_simulation.jl` to apply inverse scaling.

### Inputs/Props

- `ScalingMode`: parsed from JSONC engine config via `kind_factory!`.
- `SystemData`: the system data to potentially rescale.
- `ScalingConfig`: computed from system data analysis.

### Outputs/Behavior

- With `NoScaling`: behavior is identical to current (no changes to any values).
- With `AutoScaling`: system data values are divided by their scaling factors before model building. The resulting LP has coefficients closer to [0.1, 10] range. Simulation outputs are unscaled to original units before saving.

### Error Handling

- If all values for a variable category are zero (e.g., no hydros), the scaling factor defaults to 1.0 (no scaling for that variable).
- If a scaling factor would be less than 1e-10 (essentially zero input), default to 1.0 and log a warning.
- Follow the established `CompositeException` pattern for validation errors in JSONC parsing of the scaling mode.

## Acceptance Criteria

- [ ] Given a system with `max_storage = 50000`, when `AutoScaling` is used, then the scaled storage bounds are in [0, 1] (divided by 50000)
- [ ] Given a system with thermals costing 100 $/MWh and max_generation of 500 MW, when `AutoScaling` is used, then the generation variable bounds and cost coefficients are both scaled to single-digit ranges
- [ ] Given `NoScaling` mode, when the pipeline runs, then all values are unchanged (backward compatible)
- [ ] Given the `SDDPPolicyTaskDefinition` without a `scaling` key in JSONC, when parsed, then `NoScaling()` is used (backward compatible)
- [ ] Given `{"kind": "AutoScaling", "params": {}}`, when parsed, then an `AutoScaling` object is returned
- [ ] Given `AutoScaling` mode on the 1dtoy example, when the full pipeline runs (build, train, simulate, save), then the saved results match the unscaled pipeline results within relative tolerance of 1e-2
- [ ] Given a system where all hydro max_storage values are 0, when computing scaling factors, then the storage scaling factor defaults to 1.0

## Implementation Guide

### Suggested Approach

1. Add `ScalingMode` abstract type, `NoScaling`, and `AutoScaling` structs to `src/Engines/Engines.jl`, following the same pattern as `CutType` (simplest dimension -- parameterless structs with `kind_factory!` resolution).

2. Add constructors in `src/Engines/sddp/input.jl`:

   ```julia
   function NoScaling(::Dict{String,Any}, ::CompositeException)
       return NoScaling()
   end
   function AutoScaling(::Dict{String,Any}, ::CompositeException)
       return AutoScaling()
   end
   ```

3. Add `scaling` to `SDDPPolicyTaskDefinition` struct and update its constructor with `haskey` check for backward compat (same pattern as `duality_handler`, `forward_pass`).

4. Create `src/Engines/sddp/scaling.jl`:

   ```julia
   struct ScalingConfig
       factors::Dict{Symbol, Float64}
   end

   function compute_scaling_factors(system::SystemData)::ScalingConfig
       factors = Dict{Symbol, Float64}()
       hydros = get_hydros_entities(system)
       thermals = get_thermals_entities(system)
       buses = get_buses_entities(system)

       # Storage scaling
       max_stor = isempty(hydros) ? 1.0 : maximum(h.max_storage for h in hydros)
       factors[STORED_VOLUME] = max(max_stor, 1e-10)

       # Generation scaling
       all_gen = vcat(
           [h.max_generation for h in hydros],
           [t.max_generation for t in thermals]
       )
       max_gen = isempty(all_gen) ? 1.0 : maximum(all_gen)
       factors[HYDRO_GENERATION] = max(max_gen, 1e-10)
       factors[THERMAL_GENERATION] = max(max_gen, 1e-10)
       # ... etc
       return ScalingConfig(factors)
   end
   ```

5. Modify `SDDPModel` to hold `scaling::ScalingConfig`:

   ```julia
   struct SDDPModel <: Model
       policy_graph::SDDP.PolicyGraph
       scaling::ScalingConfig
   end
   ```

6. In `build.jl`, apply scaling before model construction. The simplest approach is to create scaled copies of the entity vectors with scaled field values using a helper function.

7. In `save_simulation.jl`, apply inverse scaling to result DataFrames before writing.

8. Include `scaling.jl` in `src/Engines/sddp.jl`.

### Key Files to Modify

- `src/Engines/Engines.jl` -- add `ScalingMode` types, update `SDDPModel`, update `SDDPPolicyTaskDefinition`
- `src/Engines/sddp/input.jl` -- add constructors for `NoScaling`, `AutoScaling`, update `SDDPPolicyTaskDefinition` constructor and builders
- `src/Engines/sddp/input-validators.jl` -- add validators for `scaling` field
- `src/Engines/sddp/scaling.jl` -- **new file**, scaling logic
- `src/Engines/sddp/build.jl` -- apply scaling before model construction
- `src/Engines/sddp/save_simulation.jl` -- apply inverse scaling to results
- `src/Engines/sddp.jl` -- include `scaling.jl`

### Patterns to Follow

- Same 6-step recipe proven in Epic 02: struct, field, constructor, `generate_*` (not needed here -- scaling is applied directly), `__build_*!`, wire into pipeline.
- Backward compat: use `haskey` check and default to `NoScaling()` when absent.
- Parameterless types use the trivial `(::Dict, ::CompositeException)` constructor pattern (same as `Serial`, `SingleCut`, etc.).

### Pitfalls to Avoid

- Do NOT try to modify JuMP variables or constraints after model construction. SDDP.jl's internal state assumes the model is built as-is.
- Do NOT scale state variable initial values inconsistently with bounds -- both must use the same factor.
- Scaling factors must be positive. Guard against zero division.
- When unscaling simulation results, handle both variable values and dual values (marginal costs). Dual values scale inversely to the constraint scaling.
- The `SystemData` struct is immutable. You will need to create new entity instances with scaled values rather than mutating in place.
- Be careful with `productivity` scaling: if generation and flow are both scaled, productivity (which converts flow to generation) may not need scaling, or it may need the ratio of the two scaling factors.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-scaling.jl`:

- Test `compute_scaling_factors` with a known system (e.g., two hydros with max_storage 50000 and 20000 returns storage factor = 50000).
- Test `compute_scaling_factors` with empty hydros (returns 1.0 for storage factor).
- Test `compute_scaling_factors` with zero-valued fields (returns 1.0 default).
- Test `ScalingConfig` construction and factor lookup.
- Test `NoScaling` and `AutoScaling` JSONC parsing.
- Test backward compat: `SDDPPolicyTaskDefinition` without `scaling` key defaults to `NoScaling`.

### Integration Tests

- Run the 1dtoy example with `AutoScaling` and verify it converges (objective value within 5% of unscaled result).
- Run the 1dtoy example with `NoScaling` and verify identical behavior to current.

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-017
- **Blocks**: None (ticket-019 is independent)

## Effort Estimate

**Points**: 4
**Confidence**: Medium
