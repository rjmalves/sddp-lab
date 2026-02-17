# ticket-011 Add Cut Type Selection

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability of new structs and adherence to codebase patterns)

## Context

### Background

SDDP.jl supports two cut types: `SDDP.SINGLE_CUT` (one cut per stage aggregating all scenarios) and `SDDP.MULTI_CUT` (one cut per scenario per stage). Multi-cut can improve convergence for problems with high stochastic variability but increases memory usage. Currently, SDDPlab does not expose this option.

### Relation to Epic

This is the sixth ticket in Epic 02. Cut type selection is a fundamental algorithmic knob that directly affects convergence behavior and memory usage.

### Current State

**`SDDPPolicyTaskDefinition`** has no cut type field. SDDP.jl defaults to `SINGLE_CUT`.

**`src/Engines/sddp/train.jl`** does not pass `cut_type` to `SDDP.train`.

**`src/Engines/sddp/save_policy.jl`** has a TODO comment about multi-cut support:

```julia
# TODO - add support for multicuts
```

## Specification

### Requirements

1. **Add `CutType` enum-like type**:
   - `abstract type CutType end`
   - `struct SingleCut <: CutType end`
   - `struct MultiCut <: CutType end`

2. **Add `cut_type` field to `SDDPPolicyTaskDefinition`**:
   - Default: `SingleCut()` for backward compatibility
   - JSONC: `"cut_type": {"kind": "SingleCut", "params": {}}` or `"cut_type": {"kind": "MultiCut", "params": {}}`

3. **Add `generate_cut_type` mapping**:
   - `SingleCut` -> `SDDP.SINGLE_CUT`
   - `MultiCut` -> `SDDP.MULTI_CUT`

4. **Pass to `SDDP.train`**: `cut_type = generate_cut_type(definition.cut_type)`

5. **Update save_policy**: Remove the TODO comment. When multi-cut is used, the cut saving logic in `__get_model_cuts` may need to handle multi-cut data differently -- investigate and handle.

6. **Backward compatibility**: If `cut_type` is not in JSONC, default to `SingleCut`.

### Inputs/Props

- `d::Dict{String,Any}`, `e::CompositeException`

### Outputs/Behavior

- Valid config returns `SingleCut` or `MultiCut` struct
- `generate_cut_type` returns `SDDP.SINGLE_CUT` or `SDDP.MULTI_CUT`

### Error Handling

- Invalid kind: handled by `__kind_factory!`

## Acceptance Criteria

- [ ] Given SDDPPolicyTaskDefinition without `cut_type`, when parsed, then `SingleCut` is used (backward compat)
- [ ] Given `{"kind": "MultiCut", "params": {}}`, when parsed, then `MultiCut()` is returned
- [ ] Given `generate_cut_type(MultiCut())`, when called, then `SDDP.MULTI_CUT` is returned
- [ ] Given 1dtoy with `MultiCut` configuration, when the pipeline runs (build -> train -> save_policy -> simulate), then no errors occur
- [ ] Given 1dtoy with `MultiCut`, when policy is saved, then cut data is correctly written

## Implementation Guide

### Suggested Approach

1. Add types in `src/Engines/Engines.jl`
2. Add constructors, validators (minimal -- no parameters to validate), mapping function
3. Add field to `SDDPPolicyTaskDefinition`, update constructor
4. Update `train.jl` to pass `cut_type`
5. Investigate `save_policy.jl` multi-cut handling: SDDP.jl's `write_cuts_to_file` should handle both cut types, but verify the JSON format and update `__process_cuts_for_intercepts` / `__process_cuts_for_state_vars` if needed
6. Remove the TODO comment in `save_policy.jl`

### Key Files to Modify

- `src/Engines/Engines.jl` -- types, updated SDDPPolicyTaskDefinition
- `src/Engines/sddp/input.jl` -- constructors, mapping
- `src/Engines/sddp/input-validators.jl` -- validators
- `src/Engines/sddp/train.jl` -- pass cut_type
- `src/Engines/sddp/save_policy.jl` -- verify multi-cut handling, remove TODO
- `test/Engines/sddp/test-cut-types.jl` -- new test file

### Patterns to Follow

Same `kind/params` factory pattern. These are simple types with no parameters (like `Serial` and `Asynchronous`).

### Pitfalls to Avoid

- `SDDP.SINGLE_CUT` and `SDDP.MULTI_CUT` are enum values (of type `SDDP.CutType`), not types. The `generate_cut_type` function returns a value, not an instance.
- Multi-cut JSON format from `SDDP.write_cuts_to_file` may differ from single-cut. Test with the 1dtoy example to verify.
- Multi-cut increases memory proportionally to the number of scenarios. Document this in the JSONC comments.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-cut-types.jl`:

- `single-cut-valid`, `multi-cut-valid`
- `generate-cut-type-single`, `generate-cut-type-multi`
- Backward compat (no `cut_type` in policy definition)

### Integration Tests

- 1dtoy with `MultiCut` runs full pipeline including save/load policy

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-005 (Epic 01 complete)
- **Blocks**: ticket-012 (wiring through pipeline)

## Effort Estimate

**Points**: 2
**Confidence**: High
