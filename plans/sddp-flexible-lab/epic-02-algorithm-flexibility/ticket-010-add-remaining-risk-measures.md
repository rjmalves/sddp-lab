# ticket-006 Add Remaining Risk Measures

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability of new structs and adherence to codebase patterns)

## Context

### Background

The SDDPEngine currently supports four risk measures: `Expectation`, `WorstCase`, `AVaR`, and `CVaR`. SDDP.jl provides several additional risk measures that are useful for experimentation: `Entropic`, `Wasserstein`, `ModifiedChiSquared`, and `ConvexCombination` (which combines multiple risk measures with weights). Adding these completes the risk measure configuration surface.

### Relation to Epic

This is the first ticket in Epic 02 (Algorithm Flexibility). It extends the existing risk measure type hierarchy following the established pattern.

### Current State

**`src/Engines/Engines.jl`** defines the risk measure type hierarchy:

```julia
abstract type RiskMeasure end
struct Expectation <: RiskMeasure end
struct WorstCase <: RiskMeasure end
struct AVaR <: RiskMeasure
    alpha::Real
end
struct CVaR <: RiskMeasure
    alpha::Real
    lambda::Real
end
```

**`src/Engines/sddp/input.jl`** has constructors with validation for each type and `generate_risk_measure` mapping functions:

```julia
function generate_risk_measure(r::Expectation)::SDDP.AbstractRiskMeasure
    return SDDP.Expectation()
end
# ... etc
```

**`src/Engines/sddp/input-validators.jl`** has validators for each risk measure type.

**SDDP.jl risk measures available but not yet exposed**:

- `SDDP.Entropic(theta)` -- entropic risk measure with parameter theta > 0
- `SDDP.Wasserstein(solver; alpha)` -- Wasserstein distance-based risk measure
- `SDDP.ModifiedChiSquared(radius; minimum_concentration)` -- modified chi-squared divergence
- `SDDP.EAVaR(beta, lambda)` -- already used by CVaR internally, but could be exposed directly
- Convex combination via `SDDP.EAVaR(beta=b, lambda=l)` or direct construction

## Specification

### Requirements

1. **Add `Entropic` risk measure**:
   - Struct: `Entropic <: RiskMeasure` with field `theta::Real`
   - Validation: `theta > 0`
   - JSONC config: `{"kind": "Entropic", "params": {"theta": 0.1}}`
   - Mapping: `generate_risk_measure(r::Entropic)` returns `SDDP.Entropic(r.theta)`

2. **Add `Wasserstein` risk measure**:
   - Struct: `WassersteinRM <: RiskMeasure` with field `alpha::Real`
   - Validation: `0 < alpha < 1`
   - JSONC config: `{"kind": "WassersteinRM", "params": {"alpha": 0.5}}`
   - Mapping: `generate_risk_measure(r::WassersteinRM)` returns `SDDP.Wasserstein(GLPK.Optimizer; alpha=r.alpha)` (note: requires a solver for the inner problem)
   - Note: The type is named `WassersteinRM` (not `Wasserstein`) to avoid a name clash with the `Distributions.Wasserstein` type

3. **Add `ModifiedChiSquared` risk measure**:
   - Struct: `ModifiedChiSquared <: RiskMeasure` with fields `radius::Real`, `minimum_concentration::Real`
   - Validation: `radius > 0`, `0 < minimum_concentration <= 1`
   - JSONC config: `{"kind": "ModifiedChiSquared", "params": {"radius": 0.1, "minimum_concentration": 0.25}}`
   - Mapping: `generate_risk_measure(r::ModifiedChiSquared)` returns `SDDP.ModifiedChiSquared(r.radius; minimum_concentration=r.minimum_concentration)`

4. **Add `ConvexCombination` risk measure**:
   - Struct: `ConvexCombination <: RiskMeasure` with field `measures::Vector{Tuple{Real, RiskMeasure}}`
   - Each tuple is `(weight, risk_measure)` where weights sum to 1.0
   - Validation: weights in (0,1], sum to 1.0 within tolerance 1e-6, each inner measure is valid
   - JSONC config:
     ```json
     {
       "kind": "ConvexCombination",
       "params": {
         "measures": [
           {
             "weight": 0.5,
             "risk_measure": { "kind": "Expectation", "params": {} }
           },
           {
             "weight": 0.5,
             "risk_measure": { "kind": "AVaR", "params": { "alpha": 0.1 } }
           }
         ]
       }
     }
     ```
   - Mapping: builds each inner measure, then returns `SDDP.ConvexCombination(Tuple{Float64, SDDP.AbstractRiskMeasure}[(w, generate_risk_measure(rm)) for (w, rm) in r.measures]...)`

### Inputs/Props

- `d::Dict{String,Any}` -- parsed JSONC dictionary
- `e::CompositeException` -- error accumulator

### Outputs/Behavior

- Valid config: returns the risk measure struct
- Invalid config: returns `nothing`, pushes errors to `e`
- `generate_risk_measure`: returns the corresponding `SDDP.AbstractRiskMeasure` subtype

### Error Handling

- Missing keys: `ErrorException("Key 'X' not found in dictionary")`
- Invalid theta: `AssertionError("Entropic theta (X) must be positive")`
- Invalid alpha: `AssertionError("Wasserstein alpha (X) must be in (0, 1)")`
- Invalid radius: `AssertionError("ModifiedChiSquared radius (X) must be positive")`
- ConvexCombination weights not summing to 1: `AssertionError("ConvexCombination weights sum to X, expected 1.0")`

## Acceptance Criteria

- [ ] Given `{"kind": "Entropic", "params": {"theta": 0.1}}`, when parsed as a risk measure, then an `Entropic(0.1)` object is returned
- [ ] Given `{"kind": "Entropic", "params": {"theta": -1.0}}`, when parsed, then `nothing` is returned with an error about theta
- [ ] Given `{"kind": "WassersteinRM", "params": {"alpha": 0.5}}`, when parsed, then a `WassersteinRM(0.5)` object is returned
- [ ] Given `{"kind": "ModifiedChiSquared", "params": {"radius": 0.1, "minimum_concentration": 0.25}}`, when parsed, then a `ModifiedChiSquared(0.1, 0.25)` object is returned
- [ ] Given a ConvexCombination config with two measures and valid weights, when parsed, then a `ConvexCombination` with two entries is returned
- [ ] Given a ConvexCombination with weights summing to 0.8, when parsed, then `nothing` is returned with a weight sum error
- [ ] Given `generate_risk_measure(Entropic(0.1))`, when called, then the result is of type `SDDP.Entropic`
- [ ] Given `generate_risk_measure(ConvexCombination(...))`, when called, then the result is of type suitable for SDDP.train's `risk_measure` parameter

## Implementation Guide

### Suggested Approach

1. **Add struct definitions** to `src/Engines/Engines.jl` after the existing risk measure structs:

   ```julia
   struct Entropic <: RiskMeasure
       theta::Real
   end

   struct WassersteinRM <: RiskMeasure
       alpha::Real
   end

   struct ModifiedChiSquared <: RiskMeasure
       radius::Real
       minimum_concentration::Real
   end

   struct ConvexCombination <: RiskMeasure
       measures::Vector{Tuple{Real, RiskMeasure}}
   end
   ```

2. **Add constructors** in `src/Engines/sddp/input.jl` following the existing pattern (Entropic, WassersteinRM, ModifiedChiSquared, ConvexCombination). Each constructor follows the 4-step validation pattern.

3. **Add validators** in `src/Engines/sddp/input-validators.jl`:
   - `__validate_entropic_keys_types!`, `__validate_entropic_content!`, etc.
   - `__validate_wasserstein_rm_keys_types!`, `__validate_wasserstein_rm_content!`, etc.
   - `__validate_modified_chi_squared_keys_types!`, `__validate_modified_chi_squared_content!`, etc.
   - `__validate_convex_combination_keys_types!`, `__validate_convex_combination_content!`, `__validate_convex_combination_consistency!`

4. **Add `generate_risk_measure` methods** in `src/Engines/sddp/input.jl`:

   ```julia
   function generate_risk_measure(r::Entropic)::SDDP.AbstractRiskMeasure
       return SDDP.Entropic(r.theta)
   end
   ```

   For WassersteinRM, the Wasserstein risk measure requires an optimizer for its inner problem. Pass `nothing` or the study's optimizer as a default, or require it as a parameter.

5. **Add exports** to `Engines.jl` for the new types.

6. **Add tests** in `test/Engines/sddp/test-risk-measure.jl`.

### Key Files to Modify

- `src/Engines/Engines.jl` -- add struct definitions and exports
- `src/Engines/sddp/input.jl` -- add constructors, `__build_*` helpers, and `generate_risk_measure` methods
- `src/Engines/sddp/input-validators.jl` -- add validator functions
- `test/Engines/sddp/test-risk-measure.jl` -- add test cases

### Patterns to Follow

Follow the exact same pattern as `AVaR` and `CVaR`:

1. Struct definition in `Engines.jl`
2. Constructor with 4-step validation in `input.jl`
3. `__build_X_internals_from_dicts!` helper in `input.jl`
4. Validators in `input-validators.jl`
5. `generate_risk_measure` mapping in `input.jl`
6. Tests mirroring existing risk measure tests

The `ConvexCombination` constructor is more complex because it contains nested risk measures. Use `__kind_factory!` to recursively build inner risk measures from their `kind/params` dictionaries.

### Pitfalls to Avoid

- `SDDP.Wasserstein` requires a solver for its inner optimization problem. Check SDDP.jl docs to determine if this is optional or required, and decide how to pass it (from the engine config, or default to the study's optimizer).
- `ConvexCombination` is recursive -- an inner measure could itself be a ConvexCombination. Ensure the parser handles this, but consider capping nesting depth at 2 for sanity.
- The `__kind_factory!` pattern resolves types by name within a module. The new risk measure types must be in scope when the factory runs. Since they are defined in the `Engines` module, this should work, but verify.
- `SDDP.Entropic` might not exist in all SDDP.jl versions -- check the minimum SDDP.jl version in Project.toml compat and verify the type is available.

## Testing Requirements

### Unit Tests

Add to `test/Engines/sddp/test-risk-measure.jl`:

- `entropic-valid`: `Entropic(Dict("theta" => 0.1), e)` returns `Entropic`
- `entropic-invalid-theta`: theta = -1.0 returns `nothing`
- `wasserstein-valid`: `WassersteinRM(Dict("alpha" => 0.5), e)` returns `WassersteinRM`
- `wasserstein-invalid-alpha`: alpha = 1.5 returns `nothing`
- `modified-chi-squared-valid`: valid params return `ModifiedChiSquared`
- `modified-chi-squared-invalid-radius`: radius = -0.1 returns `nothing`
- `convex-combination-valid`: two measures with weights 0.5, 0.5 returns `ConvexCombination`
- `convex-combination-invalid-weights`: weights sum to 0.8 returns `nothing`
- `convex-combination-invalid-inner-measure`: inner measure has invalid params returns `nothing`

Add mapping tests:

- `generate_risk_measure(Entropic(0.1))` returns correct SDDP type
- `generate_risk_measure(ModifiedChiSquared(0.1, 0.25))` returns correct SDDP type

### Integration Tests

- Existing 1dtoy example configured with `Entropic` risk measure runs the full pipeline without errors

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete, engine abstraction stabilized)
- **Blocks**: ticket-012 (wiring new options through pipeline)

## Effort Estimate

**Points**: 3
**Confidence**: High
