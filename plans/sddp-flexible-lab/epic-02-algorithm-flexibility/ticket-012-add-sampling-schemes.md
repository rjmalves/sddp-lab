# ticket-008 Add Sampling Schemes

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify correct SDDP.jl sampling API usage)

## Context

### Background

The SDDPEngine currently hardcodes `SDDP.InSampleMonteCarlo` as the sampling scheme in the `__simulate_model` function in `src/Engines/sddp/simulate.jl`. SDDP.jl provides multiple sampling schemes for both training (forward pass sampling) and simulation. This ticket makes sampling schemes configurable through JSONC, covering both training and simulation contexts.

### Relation to Epic

This is the third ticket in Epic 02. Sampling schemes are a critical experimentation knob -- they control how scenarios are selected during both policy training and simulation, directly affecting solution quality and computational cost.

### Current State

**`src/Engines/sddp/simulate.jl`** hardcodes the sampler:

```julia
sampler = SDDP.InSampleMonteCarlo(;
    max_depth = length(model.policy_graph.nodes), terminate_on_dummy_leaf = false
)
```

**`src/Engines/sddp/train.jl`** does not specify a sampling scheme, relying on SDDP.jl's default (InSampleMonteCarlo).

**`SDDPPolicyTaskDefinition`** and **`SDDPSimulationTaskDefinition`** do not have a sampling scheme field.

**SDDP.jl sampling schemes**:

- `SDDP.InSampleMonteCarlo(; max_depth, terminate_on_dummy_leaf, rollout_limit, initial_node)` -- sample from the training scenarios
- `SDDP.OutOfSampleMonteCarlo(; ...)` -- sample from a separate scenario tree (for out-of-sample evaluation)
- `SDDP.Historical(scenarios)` -- replay fixed scenario sequences
- `SDDP.PSRSamplingScheme(num_samples)` -- PSR's improved sampling
- `SDDP.SimulatorSamplingScheme(simulator)` -- user-provided simulator

## Specification

### Requirements

1. **Add `SamplingScheme` abstract type** to `src/Engines/Engines.jl`:

   ```julia
   abstract type SamplingScheme end
   ```

2. **Add `InSampleMonteCarlo` sampling scheme**:
   - Struct: `InSampleMC <: SamplingScheme` with fields `max_depth::Integer`, `terminate_on_dummy_leaf::Bool`
   - Validation: `max_depth > 0`
   - JSONC: `{"kind": "InSampleMC", "params": {"max_depth": 12, "terminate_on_dummy_leaf": false}}`
   - Mapping: returns `SDDP.InSampleMonteCarlo(; max_depth=s.max_depth, terminate_on_dummy_leaf=s.terminate_on_dummy_leaf)`

3. **Add `OutOfSampleMonteCarlo` sampling scheme**:
   - Struct: `OutOfSampleMC <: SamplingScheme` with fields `max_depth::Integer`, `terminate_on_dummy_leaf::Bool`
   - Validation: `max_depth > 0`
   - JSONC: `{"kind": "OutOfSampleMC", "params": {"max_depth": 12, "terminate_on_dummy_leaf": false}}`

4. **Add `PSRSampling` sampling scheme**:
   - Struct: `PSRSampling <: SamplingScheme` with field `num_samples::Integer`
   - Validation: `num_samples > 0`
   - JSONC: `{"kind": "PSRSampling", "params": {"num_samples": 100}}`

5. **Add `DefaultSampling` sampling scheme** (for when no explicit scheme is desired):
   - Struct: `DefaultSampling <: SamplingScheme` (no fields)
   - This produces the SDDP.jl default behavior

6. **Add sampling scheme to `SDDPPolicyTaskDefinition`**:
   - New field: `sampling_scheme::SamplingScheme`
   - Default: `DefaultSampling()` (preserves backward compatibility)
   - Pass to `SDDP.train(...; sampling_scheme = generate_sampling_scheme(definition.sampling_scheme))`

7. **Add sampling scheme to `SDDPSimulationTaskDefinition`**:
   - New field: `sampling_scheme::SamplingScheme`
   - Default: `InSampleMC` with `max_depth` derived from graph size
   - Replace the hardcoded sampler in `__simulate_model`

8. **Backward compatibility**: If `sampling_scheme` is not present in the JSONC config, default to current behavior.

### Inputs/Props

- `d::Dict{String,Any}` -- parsed JSONC dictionary
- `e::CompositeException` -- error accumulator

### Outputs/Behavior

- Valid config: returns the sampling scheme struct
- Invalid config: returns `nothing`, pushes errors to `e`
- `generate_sampling_scheme`: returns `SDDP.AbstractSamplingScheme` subtype

### Error Handling

- Standard validation error patterns
- `max_depth <= 0`: `AssertionError("InSampleMC max_depth (X) must be positive")`

## Acceptance Criteria

- [ ] Given an SDDPPolicyTaskDefinition without `sampling_scheme` in JSONC, when parsed, then `DefaultSampling` is used (backward compatible)
- [ ] Given `{"kind": "InSampleMC", "params": {"max_depth": 12, "terminate_on_dummy_leaf": false}}`, when parsed, then an `InSampleMC(12, false)` object is returned
- [ ] Given `{"kind": "PSRSampling", "params": {"num_samples": 100}}`, when parsed, then a `PSRSampling(100)` object is returned
- [ ] Given `generate_sampling_scheme(InSampleMC(12, false))`, when called, then the result is of type `SDDP.InSampleMonteCarlo`
- [ ] Given `generate_sampling_scheme(DefaultSampling())`, when called for training, then the SDDP.jl default is used
- [ ] Given the 1dtoy example configured with explicit `InSampleMC` sampling for simulation, when the pipeline runs, then simulation results are produced
- [ ] Given the existing 1dtoy example without `sampling_scheme`, when the pipeline runs, then behavior is identical to before this change

## Implementation Guide

### Suggested Approach

1. **Add abstract type and concrete structs** in `src/Engines/Engines.jl`.

2. **Add constructors and validators** in `src/Engines/sddp/input.jl` and `input-validators.jl`.

3. **Add `generate_sampling_scheme` methods** in `src/Engines/sddp/input.jl`:

   ```julia
   function generate_sampling_scheme(s::DefaultSampling)
       return SDDP.InSampleMonteCarlo()
   end
   function generate_sampling_scheme(s::InSampleMC)
       return SDDP.InSampleMonteCarlo(; max_depth=s.max_depth, terminate_on_dummy_leaf=s.terminate_on_dummy_leaf)
   end
   ```

4. **Update `SDDPPolicyTaskDefinition`**: Add `sampling_scheme` field. Update constructor and validators.

5. **Update `SDDPSimulationTaskDefinition`**: Add `sampling_scheme` field. Update constructor.

6. **Update `train.jl`**: Pass sampling scheme to SDDP.train.

7. **Update `simulate.jl`**: Replace hardcoded sampler with configurable one.

8. **Handle backward compatibility** in constructors: If `sampling_scheme` key is not in the dict, set default.

### Key Files to Modify

- `src/Engines/Engines.jl` -- add `SamplingScheme` hierarchy, update task definition structs
- `src/Engines/sddp/input.jl` -- add constructors, mapping functions, update task definition constructors
- `src/Engines/sddp/input-validators.jl` -- add validators, update task definition validators
- `src/Engines/sddp/train.jl` -- pass sampling scheme
- `src/Engines/sddp/simulate.jl` -- use configurable sampler
- `test/Engines/sddp/test-sampling-schemes.jl` -- create new test file

### Patterns to Follow

- Same `kind/params` factory pattern as risk measures and stopping criteria
- For backward compatibility, use `haskey(d, "sampling_scheme")` before building, and default to `DefaultSampling()` if missing

### Pitfalls to Avoid

- `SDDP.OutOfSampleMonteCarlo` requires a different scenario tree -- this may not be straightforward. If the implementation is complex, defer it and implement only `InSampleMC`, `PSRSampling`, and `DefaultSampling`.
- The `max_depth` parameter for simulation sampling should default to the number of graph nodes when not specified. This requires access to the model during simulation, which is already available.
- `SDDP.Historical` requires pre-computed scenario sequences. This is complex to configure via JSONC and can be deferred to a later ticket.
- Modifying `SDDPPolicyTaskDefinition` and `SDDPSimulationTaskDefinition` changes the constructor signatures -- all tests that construct these types must be updated.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-sampling-schemes.jl`:

- `default-sampling-valid`
- `insample-mc-valid`, `insample-mc-invalid-max-depth`
- `psr-sampling-valid`, `psr-sampling-invalid-num-samples`
- `generate-sampling-scheme-default`, `generate-sampling-scheme-insample-mc`

Update `test/Engines/test-engines.jl`:

- SDDPEngine construction with sampling scheme in policy and simulation
- SDDPEngine construction without sampling scheme (backward compat)

### Integration Tests

- 1dtoy with explicit `InSampleMC` sampling runs full pipeline

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete)
- **Blocks**: ticket-012 (wiring through pipeline)

## Effort Estimate

**Points**: 4
**Confidence**: Medium (OutOfSampleMC and Historical complexity may require scoping down)
