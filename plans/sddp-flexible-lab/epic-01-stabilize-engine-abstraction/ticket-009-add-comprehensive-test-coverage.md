# ticket-009 Add Comprehensive Test Coverage for Engine Abstraction and Validation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (to verify that SDDP.jl mapping function tests exercise the correct SDDP.jl API surface)

## Context

### Background

The `abstract-engine` branch has tests for the core types (convergence, risk measures, stopping criteria, parallel scheme, engine construction) and an end-to-end pipeline test, but test coverage gaps remain. The graph module has only one positive test case. The study module tests do not exercise error paths. The Lab module IO tests cover only format selection. The scenario data tests cover only valid construction and file reading. Additionally, the new schema validation infrastructure (tickets 003-006) needs comprehensive testing to verify that the migration preserved all validation behavior.

### Relation to Epic

This is the final ticket in Epic 01. It ensures the stabilized engine abstraction and the new schema validation infrastructure have comprehensive test coverage before Epic 02 extends the system with new algorithm options.

### Current State

**Existing test files** (on abstract-engine, after tickets 001-008):

- `test/Engines/test-engines.jl` -- 1 test (valid SDDPEngine construction)
- `test/Engines/sddp/test-convergence.jl` -- 5 tests (valid + invalid scenarios)
- `test/Engines/sddp/test-risk-measure.jl` -- 7 tests (valid + invalid for each risk type)
- `test/Engines/sddp/test-stopping-criteria.jl` -- 7 tests (valid + invalid for each type)
- `test/Engines/sddp/test-parallelscheme.jl` -- 2 tests (Serial, Asynchronous valid)
- `test/Scenarios/test-graph.jl` -- 1 test (valid graph construction)
- `test/Scenarios/test-scenariosdata.jl` -- 2 tests (valid from dict, valid from file)
- `test/Lab/test-io.jl` -- 2 tests (CSV and Parquet format selection)
- `test/test-study.jl` -- 7 tests (read, build, train, save_policy, load_policy, simulate, save_simulation)
- `test/test-main.jl` -- 1 test (full pipeline)
- `test/Utils/test-schema.jl` -- tests from ticket-003 (FieldRule, validate_schema!, predicates)

**Coverage gaps**:

1. Engine construction error paths (missing policy, missing simulation, invalid kind)
2. Study construction error paths (missing inputs, missing engine, invalid path)
3. Graph error paths (covered by ticket-002 tests, but additional edge cases needed)
4. Scenario data error paths (invalid seed, invalid branchings, missing inflow, missing load)
5. No tests for `generate_stopping_rule`, `generate_parallel_scheme`, `generate_risk_measure` mapping functions
6. No tests for `get_policy_definition`, `get_simulation_definition` accessors
7. No negative tests for parallel scheme (invalid kind)
8. Load representation tests with `node_id` (after ticket-007)
9. Schema validation regression tests -- verify that schema-based validators produce the same errors as the old hand-written validators for known invalid inputs
10. No tests for schema-migrated entities with edge-case inputs (boundary values, type coercion edge cases)

## Specification

### Requirements

1. **Engine construction error paths**: Test SDDPEngine with missing `policy`, missing `simulation`, and unrecognized `kind` values

2. **Study construction error paths**: Test `read_study` with non-existent directory, `Study` with missing `inputs` key, `Study` with missing `engine` key

3. **SDDP.jl mapping functions**: Test that each `generate_*` function returns the correct SDDP.jl type:
   - `generate_stopping_rule(IterationLimit(128))` returns `SDDP.IterationLimit`
   - `generate_stopping_rule(TimeLimit(60))` returns `SDDP.TimeLimit`
   - `generate_stopping_rule(LowerBoundStability(0.05, 5))` returns `SDDP.BoundStalling`
   - `generate_parallel_scheme(Serial())` returns `SDDP.Serial`
   - `generate_parallel_scheme(Asynchronous())` returns `SDDP.Asynchronous`
   - `generate_risk_measure(Expectation())` returns `SDDP.Expectation`
   - `generate_risk_measure(WorstCase())` returns `SDDP.WorstCase`
   - `generate_risk_measure(AVaR(0.5))` returns `SDDP.AVaR`
   - `generate_risk_measure(CVaR(0.2, 0.9))` returns `SDDP.EAVaR`

4. **Accessor functions**: Test `get_policy_definition` and `get_simulation_definition` return the correct types

5. **Scenario data error paths**: Test ScenariosData with invalid seed (negative), invalid branchings (zero), missing inflow, missing load

6. **Multi-example pipeline tests**: Ensure all three example cases (1dtoy, 1dsin, 1dsin_ar) pass the full pipeline test

7. **Schema validation regression tests**: For each migrated entity type, verify that:
   - Known valid inputs produce successful construction (same as before migration)
   - Known invalid inputs produce errors (same error types, similar messages)
   - Boundary values are handled correctly (e.g., `id = 0` should fail `positive()`, `id = 1` should pass)

8. **Load representation tests**: Test `DeterministicLoadValue` with `node_id`, load lookup by `(bus_id, node_id)`, and load-graph consistency validation

### Inputs/Props

- Test dictionaries mimicking JSONC config structure
- Example directory paths

### Outputs/Behavior

- All new tests pass
- Error path tests verify that `nothing` is returned and appropriate errors are pushed to `CompositeException`
- Mapping function tests verify correct SDDP.jl type construction

### Error Handling

- Tests that verify error paths should check both the return value (`=== nothing`) and the error count in the `CompositeException`

## Acceptance Criteria

- [ ] Given an SDDPEngine dict with missing `policy` key, when `SDDPEngine(d, e)` is called, then `nothing` is returned and `length(e) > 0`
- [ ] Given an SDDPEngine dict with missing `simulation` key, when `SDDPEngine(d, e)` is called, then `nothing` is returned and `length(e) > 0`
- [ ] Given a non-existent directory path, when `read_study(path)` is called, then the returned study is `nothing`
- [ ] Given `generate_stopping_rule(IterationLimit(128))`, when called, then the result is of type `SDDP.IterationLimit`
- [ ] Given `generate_risk_measure(Expectation())`, when called, then the result is of type `SDDP.Expectation`
- [ ] Given `generate_parallel_scheme(Serial())`, when called, then the result is of type `SDDP.Serial`
- [ ] Given a valid SDDPEngine, when `get_policy_definition` is called, then the result is of type `SDDPPolicyTaskDefinition`
- [ ] Given ScenariosData dict with `branchings: 0`, when constructed, then `nothing` is returned
- [ ] Given the 1dsin example, when the full pipeline is run, then no errors occur
- [ ] Given the 1dsin_ar example, when the full pipeline is run, then no errors occur
- [ ] Given a Bus dict with `id: 0`, when `Bus(d, e)` is called via schema validation, then `nothing` is returned (boundary test for `positive()` constraint)
- [ ] Given a Bus dict with `id: 1`, when `Bus(d, e)` is called via schema validation, then the Bus is successfully constructed
- [ ] Given a DeterministicLoadValue dict with `node_id` referencing a non-existent graph node, when ScenariosData is constructed, then validation fails

## Implementation Guide

### Suggested Approach

1. **Create `test/Engines/test-sddp-mappings.jl`**: New test file for the `generate_*` mapping functions and accessor functions. Import `SDDPlab.Engines` and `SDDP` to verify return types.

2. **Extend `test/Engines/test-engines.jl`**: Add negative tests for SDDPEngine construction.

3. **Extend `test/test-study.jl`**: Add negative tests for Study construction and `read_study` with invalid paths.

4. **Create `test/Scenarios/test-scenariosdata-errors.jl`** (or extend existing): Add negative test cases for ScenariosData.

5. **Extend `test/test-main.jl`**: Add pipeline tests for 1dsin and 1dsin_ar examples.

6. **Add schema regression tests**: Create `test/Utils/test-schema-regression.jl` that tests known valid/invalid inputs for each migrated entity type against the schema-based constructors.

7. **Add load representation tests**: Create or extend `test/Scenarios/test-load.jl` with tests for `node_id` field and load-graph consistency.

8. **Run the full test suite** to verify all tests pass.

### Key Files to Modify

- `test/Engines/test-engines.jl` -- add negative SDDPEngine tests
- `test/Engines/test-sddp-mappings.jl` -- create new (mapping functions + accessors)
- `test/test-study.jl` -- add negative study tests
- `test/Scenarios/test-scenariosdata.jl` -- add negative scenario tests
- `test/Scenarios/test-load.jl` -- create or extend (load representation tests)
- `test/Utils/test-schema-regression.jl` -- create new (schema regression tests)
- `test/test-main.jl` -- add multi-example pipeline tests

### Patterns to Follow

Follow the existing test patterns:

```julia
@testset "test-name" begin
    d, e = __renew(DICT)
    # Modify d to create error condition
    result = SomeType(d, e)
    @test result === nothing
    @test length(e) > 0
end
```

For mapping function tests:

```julia
@testset "generate-stopping-rule" begin
    rule = Engines.generate_stopping_rule(Engines.IterationLimit(128))
    @test typeof(rule) === SDDP.IterationLimit
end
```

For schema regression tests:

```julia
@testset "bus-schema-validation" begin
    @testset "valid-bus" begin
        d = Dict{String,Any}("id" => 1, "name" => "bus1", "deficit_cost" => 100.0)
        e = CompositeException()
        valid = validate_schema!(d, BUS_SCHEMA, e)
        @test valid == true
        @test length(e) == 0
    end
    @testset "invalid-bus-negative-id" begin
        d = Dict{String,Any}("id" => -1, "name" => "bus1", "deficit_cost" => 100.0)
        e = CompositeException()
        valid = validate_schema!(d, BUS_SCHEMA, e; entity_label = "Bus")
        @test valid == false
        @test length(e) > 0
    end
end
```

Use `@suppress` from the Suppressor package when running full pipelines to keep test output clean.

### Pitfalls to Avoid

- Do not import SDDP types directly -- access them as `SDDP.TypeName` to avoid namespace collisions
- The `Asynchronous` parallel scheme test must be careful -- `SDDP.Asynchronous()` requires distributed workers to actually run, but `generate_parallel_scheme` just constructs the scheme object
- The `read_study` function calls `cd()` internally -- tests that exercise error paths should ensure the working directory is restored after failures
- The 1dsin and 1dsin_ar example paths need to be defined relative to the test directory, similar to how `example_dir` is defined in `test/runtests.jl`
- Schema regression tests should test the SAME invalid inputs that the old hand-written validators were tested against, to verify behavior preservation

## Testing Requirements

### Unit Tests

This ticket IS the test coverage ticket. All items listed in Requirements are unit/integration tests to be written.

### Integration Tests

Multi-example pipeline tests (1dsin, 1dsin_ar) are integration tests exercising the full read -> build -> train -> simulate -> save chain.

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-001 (merge), ticket-002 (graph validators introduce new test cases), ticket-003 (schema infrastructure), ticket-004 (System migration), ticket-005 (Engine/Scenarios migration), ticket-006 (cleanup), ticket-007 (load refactor changes test data), ticket-008 (example migration)
- **Blocks**: None (this is the final ticket in Epic 01)

## Effort Estimate

**Points**: 4
**Confidence**: High
