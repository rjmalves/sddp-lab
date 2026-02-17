# ticket-016 Wire Algorithm Options Through Train and Simulate Pipelines

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (to verify that SDDP.jl API calls use the correct arguments for each algorithm option)

## Context

### Background

Tickets 010-015 each add one new algorithm knob (risk measures, stopping rules, sampling schemes, duality handlers, forward passes, cut types) as individually configurable JSONC options with their own type hierarchies and validators. However, these new options must be wired through the actual `train` and `simulate` pipeline so that they are passed as arguments to the SDDP.jl `SDDP.train` and `SDDP.simulate` calls. This ticket connects all the new options to the execution pipeline.

### Relation to Epic

This is the final ticket in Epic 02. It depends on all six algorithm option tickets (010-015) being completed, since it wires all of them through the pipeline in one pass.

### Current State

The `train` function in `src/Engines/sddp/train.jl` calls `SDDP.train` with hardcoded or partially-configurable arguments. The `simulate` function in `src/Engines/sddp/simulate.jl` calls `SDDP.simulate`. After tickets 010-015, new types exist (new risk measures, stopping rules, sampling schemes, duality handlers, forward passes, cut types) but they are not yet passed to the SDDP.jl calls.

## Specification

### Requirements

1. Update the `train` function to pass all new algorithm options to `SDDP.train`:
   - Sampling scheme from policy definition
   - Duality handler from policy definition
   - Forward pass strategy from policy definition
   - Cut type from policy definition
   - Multiple stopping rules (chained)
   - New risk measures

2. Update the `simulate` function to pass relevant options to `SDDP.simulate`:
   - Sampling scheme for simulation
   - Any simulation-specific options added in tickets 010-015

3. Update `SDDPPolicyTaskDefinition` and `SDDPSimulationTaskDefinition` to include fields for all new algorithm options (if not already done in tickets 010-015).

4. Update the `generate_*` mapping functions to cover all new types introduced in tickets 010-015.

5. Ensure all existing tests still pass and add integration tests that exercise the new options through the full pipeline.

### Inputs/Props

- `SDDPPolicyTaskDefinition` with all algorithm options configured
- `SDDPSimulationTaskDefinition` with simulation options configured

### Outputs/Behavior

- `SDDP.train` is called with all configured algorithm options
- `SDDP.simulate` is called with all configured simulation options
- Default values are used for any options not explicitly configured

### Error Handling

- Invalid combinations of algorithm options should be caught at validation time (in the individual tickets), not at wiring time

## Acceptance Criteria

- [ ] Given a policy definition with a non-default sampling scheme, when `train` is called, then `SDDP.train` receives the correct `sampling_scheme` argument
- [ ] Given a policy definition with a duality handler, when `train` is called, then `SDDP.train` receives the correct `duality_handler` argument
- [ ] Given a policy definition with a forward pass strategy, when `train` is called, then `SDDP.train` receives the correct `forward_pass` argument
- [ ] Given a policy definition with a cut type selection, when `train` is called, then `SDDP.train` receives the correct `cut_type` argument
- [ ] Given the 1dtoy example with all default options, when the full pipeline runs, then results are identical to before this change
- [ ] Given a JSONC config with a non-default sampling scheme, when the full pipeline runs end-to-end, then the configured scheme is used

## Implementation Guide

### Suggested Approach

1. Review the current `train.jl` and `simulate.jl` to understand which arguments are already passed to SDDP.jl
2. For each new algorithm option, add the corresponding argument to the SDDP.jl call
3. Add `generate_*` mapping functions for any new types not yet covered
4. Update integration tests to exercise at least one non-default value for each new option

### Key Files to Modify

- `src/Engines/sddp/train.jl` -- add new arguments to `SDDP.train` call
- `src/Engines/sddp/simulate.jl` -- add new arguments to `SDDP.simulate` call
- `src/Engines/Engines.jl` -- add new fields to task definition structs if needed
- `src/Engines/sddp/input.jl` -- add `generate_*` mapping functions for new types
- `test/test-main.jl` -- add pipeline tests with non-default options

### Patterns to Follow

- Follow the existing `generate_stopping_rule`, `generate_risk_measure`, `generate_parallel_scheme` pattern
- Each `generate_*` function dispatches on the SDDPlab type and returns the corresponding SDDP.jl type

### Pitfalls to Avoid

- Some SDDP.jl options have default values that should be preserved when the user does not configure them -- use `nothing` as the default in the task definition and only pass the argument to SDDP.jl if it is not `nothing`
- The order of arguments in `SDDP.train` matters for some keyword arguments -- check the SDDP.jl documentation
- Some algorithm options may interact (e.g., certain cut types require specific forward pass strategies) -- document any such constraints

## Testing Requirements

### Unit Tests

- Test `generate_*` functions for all new types
- Test that default values produce the expected SDDP.jl defaults

### Integration Tests

- Full pipeline test with at least one non-default algorithm option
- Full pipeline test with all defaults (regression)

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-010, ticket-011, ticket-012, ticket-013, ticket-014, ticket-015 (all algorithm option tickets)
- **Blocks**: None within Epic 02

## Effort Estimate

**Points**: 3
**Confidence**: Medium
