# ticket-006 Cleanup Validation Pipeline and Remove Dead Code

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (cleanup and verification -- no new logic)

## Context

### Background

Tickets 003-005 introduced the `FieldRule` schema infrastructure and migrated all entities (System, Engine, Scenarios, StochasticProcess) to use schema-driven validation. During the migration, some functions were retained for safety even though they may have become unreachable. This ticket performs a final cleanup pass: removing any remaining dead code, verifying that the validation pipeline is consistent across all modules, adding documentation comments to the schema module, and producing a quantitative summary of the boilerplate reduction.

### Relation to Epic

This is the sixth ticket in Epic 01 and the final validation simplification ticket. It ensures the codebase is clean before the load refactoring (ticket-007), example migration (ticket-008), and comprehensive testing (ticket-009).

### Current State

After tickets 003-005:

- `src/Utils/schema.jl` exists with `FieldRule`, `FieldConstraint`, `validate_schema!`, and predicate factories
- System entities (Bus, Line, Hydro, Thermal) use `BUS_SCHEMA`, `LINE_SCHEMA`, `HYDRO_SCHEMA`, `THERMAL_SCHEMA`
- Engine entities (IterationLimit, TimeLimit, etc.) use their respective schemas
- Scenarios entities (Node, Edge, DeterministicLoadValue, ScenariosData) use their respective schemas
- Some dead code may remain in validator files (functions that were called only by removed callers)
- The `validation-utils.jl` still exports `__validate_keys!` and `__validate_key_types!` which may still be needed by collection-level validators

## Specification

### Requirements

1. **Audit all validator files** for dead code:
   - Search for functions that are no longer called from anywhere
   - For each such function, verify it is truly dead (no callers) using grep/search across the entire `src/` and `test/` directories
   - Remove confirmed dead functions
   - Do NOT remove functions that are still called from tests (tests are legitimate callers)

2. **Verify the `validation-utils.jl` exports are still needed**:
   - `__validate_keys!` and `__validate_key_types!` may still be used by collection-level validators or by the `before_build` checks
   - Keep any function that still has callers; mark deprecated any function that will be removed in a future ticket

3. **Add documentation to `schema.jl`**:
   - Add module-level docstring explaining the schema validation approach
   - Add docstrings to `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`
   - Add docstrings to each predicate factory function
   - Follow the existing documentation style in the codebase (minimal but descriptive)

4. **Verify consistency across all migrated entities**:
   - Every entity that was migrated uses the same schema pattern
   - No entity mixes old and new patterns (except where documented -- collection-level validators use old pattern, singular entities use schema)
   - Error messages from schema validation are consistent in format

5. **Run the complete test suite** and verify all tests pass.

6. **Produce a quantitative summary** (as a comment in the PR or a note in the epic overview):
   - Total validator lines before migration (approximately 1913 lines)
   - Total validator lines after migration
   - Percentage reduction
   - Number of functions removed
   - Number of schema constants added

### Inputs/Props

- The entire `src/` directory (for dead code analysis)
- The entire `test/` directory (to verify no test callers exist for dead code)

### Outputs/Behavior

- Dead code removed from validator files
- Documentation added to `schema.jl`
- All tests still pass
- Quantitative summary of changes

### Error Handling

- N/A (this is a cleanup ticket with no new logic)

## Acceptance Criteria

- [ ] Given the `src/` directory, when searched for functions defined in validator files, then every defined function has at least one caller (no dead code)
- [ ] Given `src/Utils/schema.jl`, when opened, then it contains docstrings for all public types and functions
- [ ] Given the full test suite, when run, then all tests pass
- [ ] Given the 1dtoy example, when the full pipeline runs, then results are identical to before the cleanup
- [ ] Given the validator files, when `wc -l` is run on all of them, then the total is at least 40% less than the original 1913 lines
- [ ] Given any migrated entity constructor (e.g., `Bus(d, e)`), when reviewed, then it uses `validate_schema!` and does not call any removed function

## Implementation Guide

### Suggested Approach

1. **List all functions in validator files**:
   - Use grep to find all `function __validate_*` and `function __build_*` definitions
   - For each, search for callers across `src/` and `test/`
   - Build a dead-code list

2. **Remove dead functions** one file at a time:
   - Remove the function
   - Run tests
   - If tests pass, commit
   - If tests fail, the function is not dead -- restore and investigate

3. **Add documentation to `schema.jl`**:
   - Write docstrings following the Julia docstring convention (triple-quoted strings above functions)
   - Include usage examples in the docstrings for `validate_schema!`

4. **Count lines** before and after:
   - Use `wc -l` on all validator files plus `schema.jl`
   - Calculate the reduction

5. **Run the full test suite** one final time.

### Key Files to Modify

- All `*-validators.jl` files (potential dead code removal)
- `src/Utils/schema.jl` (add documentation)
- `src/Utils/validation-utils.jl` (potential dead code removal)

### Patterns to Follow

- Julia docstring convention: `"""\n    function_name(args)\n\nDescription.\n"""`
- Keep documentation concise -- one paragraph per function, with a usage example for the main API functions

### Pitfalls to Avoid

- Do NOT remove functions called by tests -- tests are legitimate callers
- Do NOT remove `__validate_keys!` or `__validate_key_types!` from `validation-utils.jl` without verifying they have zero callers. They may still be used by collection-level validators (e.g., `__validate_buses_main_key_type!`) that were intentionally not migrated.
- Do NOT remove `__parse_as_type!` or `__try_conversion!` -- these are called by `schema.jl` itself
- Do NOT remove the DataFrame validation functions (`__validate_dataframe!`, `__validate_columns_in_dataframe!`, etc.) -- these are used by the CSV file reading pipeline and are unrelated to the schema migration
- The quantitative summary should compare total lines in ALL validator files (including `schema.jl` as new code) vs. the pre-migration total

## Testing Requirements

### Unit Tests

- All existing tests must pass

### Integration Tests

- Full pipeline tests must pass

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-004 (System migration), ticket-005 (Engine/Scenarios migration)
- **Blocks**: None directly, but should be completed before ticket-007 (load refactoring) to ensure a clean codebase

## Effort Estimate

**Points**: 2
**Confidence**: High
