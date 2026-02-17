# ticket-007 Add Chained Stopping Rules

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability of new structs and adherence to codebase patterns)

## Context

### Background

The SDDPEngine currently supports three stopping criteria: `IterationLimit`, `TimeLimit`, and `LowerBoundStability`. SDDP.jl provides additional stopping rules and, critically, a `StoppingChain` mechanism that allows combining multiple stopping rules with AND/OR logic. This ticket adds the missing stopping rules and the chaining mechanism.

### Relation to Epic

This is the second ticket in Epic 02. It extends the stopping criteria hierarchy and adds the important `StoppingChain` concept that allows users to express complex convergence criteria like "stop after 1000 iterations OR when the bound is stable for 50 iterations AND at least 100 iterations have been completed".

### Current State

**`src/Engines/Engines.jl`** defines:

```julia
abstract type StoppingCriteria end
struct IterationLimit <: StoppingCriteria
    num_iterations::Integer
end
struct TimeLimit <: StoppingCriteria
    time_seconds::Integer
end
struct LowerBoundStability <: StoppingCriteria
    threshold::Real
    num_iterations::Integer
end
```

**`src/Engines/sddp/input.jl`** has constructors and mapping functions:

```julia
function generate_stopping_rule(s::IterationLimit)::SDDP.AbstractStoppingRule
    return SDDP.IterationLimit(s.num_iterations)
end
```

The current `Convergence` struct uses a single `stopping_criteria::StoppingCriteria`.

**SDDP.jl stopping rules not yet exposed**:

- `SDDP.Statistical(; num_replications, iteration_period, z_score, verbose, repeated_training)` -- statistical convergence test
- `SDDP.StoppingChain(rules...)` -- chain multiple rules with AND semantics (all must be satisfied)
- `SDDP.SimulationStoppingRule(; replications, period)` -- stop based on simulation bound
- `SDDP.FirstStageStoppingRule(; atol, iterations)` -- stop based on first-stage policy stability

## Specification

### Requirements

1. **Add `Statistical` stopping criteria**:
   - Struct: `Statistical <: StoppingCriteria` with fields `num_replications::Integer`, `iteration_period::Integer`, `z_score::Real`
   - Validation: `num_replications > 0`, `iteration_period > 0`, `z_score > 0`
   - JSONC: `{"kind": "Statistical", "params": {"num_replications": 100, "iteration_period": 10, "z_score": 1.96}}`
   - Mapping: `generate_stopping_rule(s::Statistical)` returns `SDDP.Statistical(; num_replications=s.num_replications, iteration_period=s.iteration_period, z_score=s.z_score)`

2. **Add `SimulationStopping` stopping criteria**:
   - Struct: `SimulationStopping <: StoppingCriteria` with fields `replications::Integer`, `period::Integer`
   - Validation: `replications > 0`, `period > 0`
   - JSONC: `{"kind": "SimulationStopping", "params": {"replications": 100, "period": 5}}`

3. **Add `FirstStageStopping` stopping criteria**:
   - Struct: `FirstStageStopping <: StoppingCriteria` with fields `atol::Real`, `iterations::Integer`
   - Validation: `atol > 0`, `iterations > 0`
   - JSONC: `{"kind": "FirstStageStopping", "params": {"atol": 1e-3, "iterations": 5}}`

4. **Modify `Convergence` to support multiple stopping criteria**:
   - Change `stopping_criteria::StoppingCriteria` to `stopping_criteria::Vector{StoppingCriteria}`
   - In JSONC, `stopping_criteria` can be either a single object (backward compatible) or an array of objects
   - When multiple criteria are provided, they are passed as separate entries to `SDDP.train`'s `stopping_rules` vector (SDDP.jl treats multiple stopping rules with OR semantics by default)

5. **Add `StoppingChain` stopping criteria**:
   - Struct: `StoppingChain <: StoppingCriteria` with field `rules::Vector{StoppingCriteria}`
   - This wraps multiple rules with AND semantics (all must be satisfied simultaneously)
   - JSONC:
     ```json
     {
       "kind": "StoppingChain",
       "params": {
         "rules": [
           { "kind": "IterationLimit", "params": { "num_iterations": 100 } },
           {
             "kind": "LowerBoundStability",
             "params": { "threshold": 0.05, "num_iterations": 10 }
           }
         ]
       }
     }
     ```
   - Mapping: `generate_stopping_rule(s::StoppingChain)` returns `SDDP.StoppingChain([generate_stopping_rule(r) for r in s.rules]...)`

### Inputs/Props

- `d::Dict{String,Any}` -- parsed JSONC dictionary
- `e::CompositeException` -- error accumulator

### Outputs/Behavior

- Valid config: returns the stopping criteria struct(s)
- Invalid config: returns `nothing`, pushes errors to `e`
- The `generate_stopping_rule` function returns SDDP.jl stopping rule objects

### Error Handling

- Standard validation errors following existing patterns
- StoppingChain with empty rules list: `AssertionError("StoppingChain must have at least one rule")`

## Acceptance Criteria

- [ ] Given `{"kind": "Statistical", "params": {"num_replications": 100, "iteration_period": 10, "z_score": 1.96}}`, when parsed, then a `Statistical` object is returned
- [ ] Given `{"kind": "Statistical", "params": {"num_replications": 0, ...}}`, when parsed, then `nothing` is returned
- [ ] Given `Convergence` with `stopping_criteria` as a single object, when parsed, then backward compatibility is maintained (single StoppingCriteria returned)
- [ ] Given `Convergence` with `stopping_criteria` as an array of two objects, when parsed, then a vector of two StoppingCriteria is returned
- [ ] Given a `StoppingChain` with two inner rules, when `generate_stopping_rule` is called, then an `SDDP.StoppingChain` is returned
- [ ] Given the 1dtoy example configured with `Statistical` stopping, when the pipeline runs, then no errors occur
- [ ] Given the 1dtoy example configured with multiple stopping criteria (array), when the pipeline runs, then all criteria are passed to SDDP.train

## Implementation Guide

### Suggested Approach

1. **Add new struct definitions** in `src/Engines/Engines.jl` after existing stopping criteria.

2. **Add constructors and validators** following the same pattern as `IterationLimit`, `TimeLimit`, `LowerBoundStability`.

3. **Modify `Convergence` struct**:
   - Change field type to `stopping_criteria::Union{StoppingCriteria, Vector{StoppingCriteria}}`
   - Or better: always normalize to `Vector{StoppingCriteria}` during construction. If a single dict is provided, wrap it in a vector.
   - Update `__build_stopping_criteria!` to handle both dict and vector inputs.

4. **Update `train.jl`**: The `Lab.train` function currently extracts a single stopping rule. Change it to build a vector:

   ```julia
   stopping_rules = [generate_stopping_rule(sc) for sc in get_stopping_criteria(definition.convergence)]
   ```

   Where `get_stopping_criteria` always returns a vector.

5. **Add `generate_stopping_rule` methods** for the new types.

6. **Update validators** in `input-validators.jl`.

### Key Files to Modify

- `src/Engines/Engines.jl` -- add struct definitions, update Convergence field type
- `src/Engines/sddp/input.jl` -- add constructors, helpers, mapping functions; update Convergence constructor
- `src/Engines/sddp/input-validators.jl` -- add validators for new types, update Convergence validators
- `src/Engines/sddp/train.jl` -- update to handle vector of stopping rules
- `test/Engines/sddp/test-stopping-criteria.jl` -- add tests for new types
- `test/Engines/sddp/test-convergence.jl` -- add tests for multi-criteria convergence

### Patterns to Follow

- Same 4-step validation pattern as existing stopping criteria
- The `__kind_factory!` function already supports vector inputs (`typeof(factory_d) === Vector{Dict{String,Any}}`) so the stopping_criteria array case may already work if the field is properly set up

### Pitfalls to Avoid

- Backward compatibility: existing JSONC configs with a single `stopping_criteria` object must still work. The parser should detect whether the value is a dict (single) or array (multiple) and handle both.
- `SDDP.StoppingChain` uses AND semantics while multiple entries in `stopping_rules` use OR semantics. Make this distinction clear in error messages and documentation.
- The `Convergence` struct currently has `get_stopping_criteria` returning a single value. This accessor must be updated to return a vector.
- Check that `SDDP.Statistical` and other rules are available in the SDDP.jl version specified in Project.toml compat.

## Testing Requirements

### Unit Tests

Add to `test/Engines/sddp/test-stopping-criteria.jl`:

- `statistical-valid`, `statistical-invalid-replications`, `statistical-invalid-z_score`
- `simulation-stopping-valid`, `simulation-stopping-invalid-replications`
- `first-stage-stopping-valid`, `first-stage-stopping-invalid-atol`
- `stopping-chain-valid` (two inner rules)
- `stopping-chain-empty-rules` (should fail)

Add to `test/Engines/sddp/test-convergence.jl`:

- `convergence-single-stopping-criteria` (backward compat)
- `convergence-multiple-stopping-criteria` (array of two criteria)
- `convergence-with-stopping-chain`

### Integration Tests

- 1dtoy with `Statistical` stopping rule runs pipeline without errors

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete)
- **Blocks**: ticket-012 (wiring through pipeline)

## Effort Estimate

**Points**: 3
**Confidence**: High
