# ticket-049 Adaptive Model-Derived Variable Magnitudes

## Context

### Background

The `VARIABLE_UNITS_REGISTRY` in `src/Utils/variable-units.jl` (lines 8-19) contains hardcoded `min_magnitude` and `max_magnitude` values for each registered variable. For example, `THERMAL_GENERATION` has a hardcoded `max_magnitude` of `10_000.0` MW. The `get_coefficient_magnitude_report` function (lines 30-70) compares actual model variable bounds against these hardcoded constants to compute `magnitude_ratio`. This approach has two problems: (1) the hardcoded values are arbitrary and may not match the actual system being modeled; (2) adding new variable types requires manually updating the registry with guessed magnitudes.

### Relation to Epic

This is an independent robustness improvement in Epic 12. It makes the magnitude reporting adaptive to the actual model, improving the accuracy of LP conditioning diagnostics introduced in Epic 03 (ticket-017, ticket-018).

### Current State

- `VariableUnitInfo` struct (line 1-6): `variable::Symbol`, `unit::PhysicalUnit`, `min_magnitude::Float64`, `max_magnitude::Float64`
- `VARIABLE_UNITS_REGISTRY` (lines 8-19): hardcoded dict with 10 entries (STORED_VOLUME, HYDRO_GENERATION, THERMAL_GENERATION, TURBINED_FLOW, SPILLAGE, INFLOW, DEFICIT, LOAD, DIRECT_EXCHANGE, REVERSE_EXCHANGE)
- `get_coefficient_magnitude_report(model)` (lines 30-70): iterates `VARIABLE_UNITS_REGISTRY`, extracts bounds via `_extract_bounds`, computes `_compute_magnitude_ratio` against hardcoded `max_magnitude`
- `_extract_bounds(vars)` (lines 72-86): collects `JuMP.VariableRef` from arrays, extracts lower/upper bounds
- `_collect_variables(vars)` (lines 88-104): handles scalars, arrays, and state variables (`.in`/`.out`)
- Variables NOT in the registry (e.g., `NC_GENERATION`, `CONTRACT_DISPATCH`, `PUMPED_FLOW`, `BLOCK_STORAGE`) are not reported

## Specification

### Requirements

1. Add a new function `compute_model_magnitudes(model::SDDP.PolicyGraph)::Dict{Symbol, VariableUnitInfo}` that introspects the built SDDP model to extract actual variable bounds across all nodes
2. For each variable symbol registered in `VARIABLE_UNITS_REGISTRY` (and any additional block-indexed variables found in the model), compute:
   - `min_magnitude = minimum of abs(lb) across all instances (all nodes, all indices)`
   - `max_magnitude = maximum of abs(ub) across all instances (all nodes, all indices)`
3. Return a new dict with `VariableUnitInfo` entries populated from model data instead of hardcoded constants
4. The hardcoded `VARIABLE_UNITS_REGISTRY` becomes a fallback: if a variable has no bounds in any node's subproblem, use the hardcoded values
5. Update `get_coefficient_magnitude_report` to accept an optional `magnitudes` dict parameter. When provided, use model-derived magnitudes instead of the hardcoded registry.
6. Add warnings when:
   - A variable in the registry has NO bounds at all in any node (unbounded) -- `@warn "Variable $sym has no bounds in any subproblem"`
   - The magnitude ratio (max of actual bounds / model-derived max magnitude) exceeds 10.0 or is below 0.01 -- `@warn "Variable $sym magnitude ratio is $ratio (threshold: 0.01 - 10.0)"`
7. The magnitude computation must aggregate across ALL nodes in the SDDP `PolicyGraph`, not just one node -- different nodes may have different bounds (e.g., different hydro storage limits per cascade configuration)

### Inputs/Props

- `SDDP.PolicyGraph` (the built model, from `Lab.build`)
- `VARIABLE_UNITS_REGISTRY` (fallback for unbounded variables)

### Outputs/Behavior

- `compute_model_magnitudes` returns a `Dict{Symbol, VariableUnitInfo}` with model-derived magnitudes
- `get_coefficient_magnitude_report` optionally uses model-derived magnitudes
- Warnings emitted for unbounded variables and extreme magnitude ratios

### Error Handling

- If a node's subproblem does not contain a registered variable (e.g., `NC_GENERATION` absent when no non-controllable generators exist), skip it silently
- If `_safe_lower_bound` or `_safe_upper_bound` returns `NaN`, treat as unbounded for that variable instance
- Never throw -- always use `@warn` for advisory messages

## Acceptance Criteria

- [ ] Given an SDDP model built from the `1dtoy` example, when `compute_model_magnitudes(model.policy_graph)` is called, then the returned dict contains entries for `THERMAL_GENERATION` with `max_magnitude` equal to the maximum `max_generation` across all thermals (100.0 from the example), not the hardcoded 10_000.0
- [ ] Given an SDDP model with `DEFICIT` bounded at `[0, Inf)` (lower bound only), when `compute_model_magnitudes` is called, then the `DEFICIT` entry has `max_magnitude` from the hardcoded fallback (50_000.0) and a `@warn` about unbounded variable is emitted
- [ ] Given the model-derived magnitudes dict, when `get_coefficient_magnitude_report(subproblem_model; magnitudes=model_mags)` is called, then the `expected_max_magnitude` column uses model-derived values instead of hardcoded constants
- [ ] Given `compute_model_magnitudes` called on a model with 4 stages, when the function completes, then the magnitudes aggregate bounds across all 4 stage subproblems (not just stage 1)
- [ ] Given the existing `get_coefficient_magnitude_report(model)` call without the `magnitudes` parameter, when called, then behavior is identical to the current implementation (backward compatible)

## Implementation Guide

### Suggested Approach

1. Add `compute_model_magnitudes` to `src/Utils/variable-units.jl`:

   ```julia
   function compute_model_magnitudes(
       policy_graph::SDDP.PolicyGraph
   )::Dict{Symbol, VariableUnitInfo}
       result = Dict{Symbol, VariableUnitInfo}()

       # Collect bounds across all nodes
       global_bounds = Dict{Symbol, Tuple{Vector{Float64}, Vector{Float64}}}()

       for (node_key, node) in policy_graph.nodes
           sp = node.subproblem
           for (sym, info) in VARIABLE_UNITS_REGISTRY
               vars = try sp[sym] catch; continue end
               lb_values, ub_values = _extract_bounds(vars)
               if !haskey(global_bounds, sym)
                   global_bounds[sym] = (Float64[], Float64[])
               end
               append!(global_bounds[sym][1], lb_values)
               append!(global_bounds[sym][2], ub_values)
           end
       end

       for (sym, info) in VARIABLE_UNITS_REGISTRY
           if haskey(global_bounds, sym)
               lbs, ubs = global_bounds[sym]
               finite_lbs = filter(isfinite, lbs)
               finite_ubs = filter(isfinite, ubs)

               if isempty(finite_lbs) && isempty(finite_ubs)
                   @warn "Variable $sym has no finite bounds in any subproblem, using fallback"
                   result[sym] = info  # fallback to hardcoded
               else
                   min_mag = isempty(finite_lbs) ? 0.0 : minimum(abs.(finite_lbs))
                   max_mag = isempty(finite_ubs) ? info.max_magnitude : maximum(abs.(finite_ubs))
                   max_mag = max(max_mag, isempty(finite_lbs) ? 0.0 : maximum(abs.(finite_lbs)))
                   result[sym] = VariableUnitInfo(sym, info.unit, min_mag, max_mag)
               end
           end
       end

       return result
   end
   ```

2. Update `get_coefficient_magnitude_report` to accept optional magnitudes:

   ```julia
   function get_coefficient_magnitude_report(
       model::JuMP.Model;
       magnitudes::Dict{Symbol, VariableUnitInfo} = VARIABLE_UNITS_REGISTRY
   )::DataFrame
       # ... existing logic, but use `magnitudes` instead of `VARIABLE_UNITS_REGISTRY`
   end
   ```

3. Add magnitude ratio warning after computing the report (in the diagnostics pipeline, not in the report function itself).

### Key Files to Modify

- `src/Utils/variable-units.jl` -- add `compute_model_magnitudes`, update `get_coefficient_magnitude_report` signature
- `src/Engines/sddp/diagnostics.jl` -- call `compute_model_magnitudes` after build and pass to report (if diagnostics are enabled)
- `test/Utils/test-variable-units-report.jl` -- add tests

### Patterns to Follow

- Follow the existing `_extract_bounds` / `_collect_variables` pattern for safe bound extraction
- Follow the `SDDP.PolicyGraph` iteration pattern: `for (node_key, node) in policy_graph.nodes` with `node.subproblem` for the JuMP model
- The `Utils` module already imports `SDDP` indirectly through `Lab` -- but if direct `SDDP.PolicyGraph` type annotation is needed, add the import

### Pitfalls to Avoid

- Do NOT mutate `VARIABLE_UNITS_REGISTRY` -- the model-derived magnitudes are a separate dict
- The `SDDP.PolicyGraph` node keys can be `Int` or `Tuple{Int, Int}` (Markov) -- use generic iteration
- Some variables (e.g., `HYDRO_GENERATION`) are JuMP expressions, not variables -- `_extract_bounds` only works on `JuMP.VariableRef`. The existing code already handles this by catching the error (lines 40-44)
- The `Utils` module may not have direct access to `SDDP.PolicyGraph` type -- check imports and add `using SDDP: SDDP` if needed, or accept `Any` and do runtime type check
- Performance: iterating all nodes once is O(nodes \* variables), which is acceptable since this runs once after build

### Out of Scope

- Changing the auto-scaling algorithm (`src/Engines/sddp/scaling.jl`) to use model-derived magnitudes
- Adding new variable types to the registry
- Changing the `PhysicalUnit` system

## Testing Requirements

### Unit Tests

Add to `test/Utils/test-variable-units-report.jl`:

- `"model-derived-magnitudes-bounded"` -- build a mock model with known bounds, call `compute_model_magnitudes`, verify max_magnitude matches actual upper bound (not hardcoded)
- `"model-derived-magnitudes-unbounded-fallback"` -- build a model with an unbounded variable, verify fallback to hardcoded value
- `"report-with-custom-magnitudes"` -- call `get_coefficient_magnitude_report(model; magnitudes=custom)`, verify `expected_max_magnitude` uses custom values
- `"backward-compat-no-magnitudes-param"` -- call `get_coefficient_magnitude_report(model)` without parameter, verify identical to current behavior

### Integration Tests

- Build an SDDP model from `1dtoy`, call `compute_model_magnitudes`, verify entries for variables present in the model

### E2E Tests

- None required -- diagnostics pipeline integration is optional and tested via integration tests

## Dependencies

- **Blocked By**: None (independent)
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Medium (depends on SDDP.PolicyGraph internal API stability for node iteration)
