# ticket-009 Add Duality Handlers

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability of new structs and adherence to codebase patterns)

## Context

### Background

SDDP.jl provides multiple duality handlers that control how cuts are generated from dual information. The choice of duality handler can significantly affect convergence speed and solution quality, especially for problems with integer variables or non-linear constraints. Currently, SDDPlab does not expose duality handler configuration at all -- SDDP.jl's default (`ContinuousConicDuality`) is used implicitly.

### Relation to Epic

This is the fourth ticket in Epic 02. Duality handlers are an important experimentation knob for advanced SDDP research, especially when exploring Lagrangian relaxation approaches or strengthened formulations.

### Current State

**`SDDPPolicyTaskDefinition`** has fields: `convergence`, `risk_measure`, `parallel_scheme` -- no duality handler field.

**`src/Engines/sddp/train.jl`** calls `SDDP.train(...)` without specifying a `duality_handler` keyword argument, so SDDP.jl uses its default.

**SDDP.jl duality handlers**:

- `SDDP.ContinuousConicDuality()` -- default, LP duality for continuous problems
- `SDDP.LagrangianDuality(; method, ...)` -- Lagrangian relaxation for problems with integer variables
- `SDDP.StrengthenedConicDuality()` -- tighter cuts via strengthened duality
- `SDDP.BanditDuality(handlers...)` -- bandit algorithm to adaptively select among multiple handlers

## Specification

### Requirements

1. **Add `DualityHandler` abstract type** to `src/Engines/Engines.jl`

2. **Add `ContinuousConicDuality` handler**:
   - Struct: `ContinuousConicDualityHandler <: DualityHandler` (no fields)
   - JSONC: `{"kind": "ContinuousConicDualityHandler", "params": {}}`

3. **Add `StrengthenedConicDuality` handler**:
   - Struct: `StrengthenedConicDualityHandler <: DualityHandler` (no fields)
   - JSONC: `{"kind": "StrengthenedConicDualityHandler", "params": {}}`

4. **Add `LagrangianDuality` handler**:
   - Struct: `LagrangianDualityHandler <: DualityHandler` (no fields for now -- method selection can be added later)
   - JSONC: `{"kind": "LagrangianDualityHandler", "params": {}}`

5. **Add `BanditDuality` handler**:
   - Struct: `BanditDualityHandler <: DualityHandler` with field `handlers::Vector{DualityHandler}`
   - JSONC: `{"kind": "BanditDualityHandler", "params": {"handlers": [...]}}`
   - Validation: at least 2 handlers in the vector

6. **Add `DefaultDuality` handler** (for backward compatibility when not specified):
   - Struct: `DefaultDuality <: DualityHandler` (no fields)
   - Maps to no explicit argument (SDDP.jl uses its default)

7. **Add `duality_handler` field to `SDDPPolicyTaskDefinition`**:
   - Default: `DefaultDuality()` when not present in JSONC
   - Pass to `SDDP.train(...; duality_handler = generate_duality_handler(definition.duality_handler))`

### Inputs/Props

- `d::Dict{String,Any}` -- parsed JSONC dictionary
- `e::CompositeException` -- error accumulator

### Outputs/Behavior

- Valid config: returns the duality handler struct
- Invalid config: returns `nothing`, pushes errors to `e`
- `generate_duality_handler`: returns the corresponding SDDP.jl duality handler

### Error Handling

- BanditDuality with fewer than 2 handlers: `AssertionError("BanditDualityHandler must have at least 2 handlers")`

## Acceptance Criteria

- [ ] Given SDDPPolicyTaskDefinition without `duality_handler`, when parsed, then `DefaultDuality` is used (backward compatible)
- [ ] Given `{"kind": "ContinuousConicDualityHandler", "params": {}}`, when parsed, then a `ContinuousConicDualityHandler` object is returned
- [ ] Given `{"kind": "StrengthenedConicDualityHandler", "params": {}}`, when parsed, then the correct handler is returned
- [ ] Given `{"kind": "LagrangianDualityHandler", "params": {}}`, when parsed, then a `LagrangianDualityHandler` object is returned
- [ ] Given a `BanditDualityHandler` with two inner handlers, when parsed, then a valid `BanditDualityHandler` is returned
- [ ] Given `generate_duality_handler(ContinuousConicDualityHandler())`, when called, then the result is `SDDP.ContinuousConicDuality()`
- [ ] Given the 1dtoy example with `StrengthenedConicDualityHandler`, when the pipeline runs, then no errors occur

## Implementation Guide

### Suggested Approach

1. Add abstract type and structs in `src/Engines/Engines.jl`
2. Add constructors, validators, mapping functions following established patterns
3. Add `duality_handler` field to `SDDPPolicyTaskDefinition`
4. Update `train.jl` to pass duality handler
5. Handle backward compat: default to `DefaultDuality` when key missing

### Key Files to Modify

- `src/Engines/Engines.jl` -- types, updated SDDPPolicyTaskDefinition
- `src/Engines/sddp/input.jl` -- constructors and mapping functions
- `src/Engines/sddp/input-validators.jl` -- validators
- `src/Engines/sddp/train.jl` -- pass duality_handler to SDDP.train
- `test/Engines/sddp/test-duality-handlers.jl` -- new test file

### Patterns to Follow

Same pattern as risk measures and stopping criteria: struct, 4-step constructor, validators, generate\_\* mapping, tests.

### Pitfalls to Avoid

- `SDDP.LagrangianDuality` requires specific solver capabilities. Verify it works with GLPK.
- `SDDP.BanditDuality` takes handlers as positional arguments, not a vector. Splat the vector.
- The `DefaultDuality` handler should result in NOT passing `duality_handler` to `SDDP.train` at all (rather than passing the default explicitly), to avoid version compatibility issues.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-duality-handlers.jl`:

- Valid construction for each handler type
- BanditDuality with insufficient handlers
- Mapping function for each handler
- Backward compat (no duality_handler in engine config)

### Integration Tests

- 1dtoy with explicit `ContinuousConicDualityHandler` runs pipeline

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete)
- **Blocks**: ticket-012 (wiring through pipeline)

## Effort Estimate

**Points**: 3
**Confidence**: High
