# ticket-010 Add Forward Pass Strategies

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability of new structs and adherence to codebase patterns)

## Context

### Background

SDDP.jl provides multiple forward pass strategies that control how decisions are made during the forward pass of the SDDP algorithm. Different strategies can improve convergence or explore the state space more effectively. Currently, SDDPlab does not expose forward pass configuration -- SDDP.jl's default (`DefaultForwardPass`) is used implicitly.

### Relation to Epic

This is the fifth ticket in Epic 02. Forward pass strategies are a key research knob, particularly the `RiskAdjustedForwardPass` and `RegularizedForwardPass` which can significantly improve convergence for risk-averse problems.

### Current State

**`SDDPPolicyTaskDefinition`** has no forward pass field.

**`src/Engines/sddp/train.jl`** does not specify `forward_pass` in the `SDDP.train` call.

**SDDP.jl forward passes**:

- `SDDP.DefaultForwardPass()` -- standard forward simulation
- `SDDP.RevisitingForwardPass(period, sub_pass)` -- periodically revisit previous scenarios
- `SDDP.RiskAdjustedForwardPass(; forward_pass)` -- risk-adjusted forward sampling
- `SDDP.AlternativeForwardPass(forward_pass)` -- alternate between passes
- `SDDP.RegularizedForwardPass(; rho)` -- regularized forward pass with penalty parameter

## Specification

### Requirements

1. **Add `ForwardPassStrategy` abstract type** to `src/Engines/Engines.jl`

2. **Add concrete forward pass types**:
   - `DefaultForwardPassStrategy <: ForwardPassStrategy` (no fields) -- backward compat default
   - `RevisitingForwardPassStrategy <: ForwardPassStrategy` with fields `period::Integer`
   - `RiskAdjustedForwardPassStrategy <: ForwardPassStrategy` (no fields, wraps default inner pass)
   - `RegularizedForwardPassStrategy <: ForwardPassStrategy` with field `rho::Real`

3. **Validation**:
   - `RevisitingForwardPassStrategy`: `period > 0`
   - `RegularizedForwardPassStrategy`: `rho > 0`

4. **Add `forward_pass` field to `SDDPPolicyTaskDefinition`**:
   - Default: `DefaultForwardPassStrategy()` when not in JSONC
   - Pass to `SDDP.train(...; forward_pass = generate_forward_pass(definition.forward_pass))`

5. **Backward compatibility**: If `forward_pass` is not in the JSONC, default to `DefaultForwardPassStrategy()`

### Inputs/Props

- `d::Dict{String,Any}`, `e::CompositeException`

### Outputs/Behavior

- Valid config returns struct; invalid returns `nothing`
- `generate_forward_pass` returns SDDP.jl forward pass object

### Error Handling

- Standard validation patterns

## Acceptance Criteria

- [ ] Given SDDPPolicyTaskDefinition without `forward_pass`, when parsed, then `DefaultForwardPassStrategy` is used
- [ ] Given `{"kind": "RegularizedForwardPassStrategy", "params": {"rho": 0.1}}`, when parsed, then the correct struct is returned
- [ ] Given `generate_forward_pass(RegularizedForwardPassStrategy(0.1))`, when called, then result is `SDDP.RegularizedForwardPass(; rho=0.1)`
- [ ] Given 1dtoy with `RiskAdjustedForwardPassStrategy`, when pipeline runs, then no errors

## Implementation Guide

### Suggested Approach

1. Add types in `src/Engines/Engines.jl`
2. Add constructors, validators, mapping functions
3. Add field to `SDDPPolicyTaskDefinition`
4. Update `train.jl`
5. Handle backward compat with `haskey` check

### Key Files to Modify

- `src/Engines/Engines.jl` -- types, updated SDDPPolicyTaskDefinition
- `src/Engines/sddp/input.jl` -- constructors, mapping functions
- `src/Engines/sddp/input-validators.jl` -- validators
- `src/Engines/sddp/train.jl` -- pass forward_pass
- `test/Engines/sddp/test-forward-passes.jl` -- new test file

### Patterns to Follow

Same pattern as other algorithm options.

### Pitfalls to Avoid

- `SDDP.RevisitingForwardPass` takes a `sub_pass` argument. For simplicity, default to `SDDP.DefaultForwardPass()` as the inner pass.
- `DefaultForwardPassStrategy` should result in NOT passing `forward_pass` to `SDDP.train` (use SDDP.jl default).
- Check SDDP.jl version compatibility for all forward pass types.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-forward-passes.jl`:

- Valid construction for each type
- Invalid parameters (negative period, negative rho)
- Mapping functions
- Backward compat

### Integration Tests

- 1dtoy with `RegularizedForwardPassStrategy` runs pipeline

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete)
- **Blocks**: ticket-012 (wiring through pipeline)

## Effort Estimate

**Points**: 3
**Confidence**: High
