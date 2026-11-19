# ticket-005 Migrate Engine and Scenarios Entities to Schema Validation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (mechanical migration of existing validation logic to schema tables)

## Context

### Background

Ticket-003 introduced the `FieldRule` schema infrastructure and ticket-004 migrated System entities (Bus, Line, Hydro, Thermal). This ticket completes the schema migration by converting the remaining entities: Engine module types (IterationLimit, TimeLimit, LowerBoundStability, Convergence, Serial, Asynchronous, Expectation, WorstCase, AVaR, CVaR, SDDPPolicyTaskDefinition, SDDPSimulationTaskDefinition, SDDPEngine), Scenarios module types (Node, Edge, Graph, DeterministicLoadValue, DeterministicLoad, ScenariosData, InflowScenarios), and StochasticProcess module types (Naive, AutoRegressive).

### Relation to Epic

This is the fifth ticket in Epic 01. It completes the schema migration across all modules. After this ticket, the validation pipeline boilerplate is reduced by approximately 40-50% in line count, and the pattern is established for all future entities added in later epics.

### Current State

After ticket-004, the System module entities use schema validation. The remaining entities still use the old hand-written pattern.

**Engine module** (`src/Engines/sddp/input-validators.jl`, 511 lines) is the heaviest boilerplate:

- 12 entity types, each with the 4-step pattern
- Many have empty stubs: `__validate_serial_keys_types!`, `__validate_serial_content!`, `__validate_serial_consistency!`, `__build_serial_internals_from_dicts!` all just `return true`
- The `input-validators.jl` file alone has ~25 functions that return `true`
- The `input.jl` file (408 lines) contains 12 constructors all following the identical 4-step pattern

**Scenarios module** (`src/Scenarios/`):

- `graph-validators.jl` (239 lines) -- recently implemented in ticket-002, has more substance than stubs
- `load-validators.jl` (109 lines) -- DeterministicLoadValue and DeterministicLoad validators
- `scenariosdata-validators.jl` (84 lines) -- ScenariosData validators
- `inflow-validators.jl` (119 lines) -- InflowScenarios validators

**StochasticProcess module** (`src/StochasticProcess/`):

- `naive-validators.jl` (63 lines) -- Naive stochastic process validators
- `autoregressive-validators.jl` (96 lines) -- AutoRegressive validators

## Specification

### Requirements

1. **Define schema constants for Engine entities**:

   ```julia
   # Stopping criteria
   const ITERATION_LIMIT_SCHEMA = [
       FieldRule("num_iterations", Integer; constraints = [positive()]),
   ]

   const TIME_LIMIT_SCHEMA = [
       FieldRule("time_seconds", Integer; constraints = [positive()]),
   ]

   const LOWER_BOUND_STABILITY_SCHEMA = [
       FieldRule("threshold", Real; constraints = [positive(), in_range(0.0, 1.0)]),
       FieldRule("num_iterations", Integer; constraints = [positive()]),
   ]

   const CONVERGENCE_SCHEMA = [
       FieldRule("min_iterations", Integer; constraints = [positive()]),
       FieldRule("max_iterations", Integer; constraints = [positive()]),
   ]
   # Note: Convergence also has a "stopping_criteria" key but it is a built object,
   # so it stays as a manual check in the before_build / after_build pattern.

   # Risk measures
   const AVAR_SCHEMA = [
       FieldRule("alpha", Real; constraints = [in_range(0.0, 1.0)]),
   ]

   const CVAR_SCHEMA = [
       FieldRule("alpha", Real; constraints = [in_range(0.0, 1.0)]),
       FieldRule("lambda", Real; constraints = [in_range(0.0, 1.0)]),
   ]

   # Empty schemas for parameterless types
   const EMPTY_SCHEMA = FieldRule[]

   # SDDPSimulationTaskDefinition
   const SDDP_SIMULATION_SCHEMA = [
       FieldRule("num_simulated_series", Integer; constraints = [positive()]),
   ]
   ```

2. **Define schema constants for Scenarios entities**:

   ```julia
   const DETERMINISTIC_LOAD_VALUE_SCHEMA = [
       FieldRule("bus_id", Integer; constraints = [positive()]),
       FieldRule("stage_index", Integer; constraints = [positive()]),
       FieldRule("value", Real),
   ]

   const SCENARIOS_SCHEMA = [
       FieldRule("seed", Integer),
       FieldRule("initial_season", Integer; constraints = [positive()]),
       FieldRule("branchings", Integer; constraints = [positive()]),
   ]
   # Note: "graph", "inflow", "load" are built objects -- stay in manual before_build / after_build

   const NODE_SCHEMA = [
       FieldRule("id", Integer; constraints = [positive()]),
       FieldRule("season", Integer; constraints = [positive()]),
   ]

   const EDGE_SCHEMA = [
       FieldRule("from", Integer; constraints = [non_negative()]),
       FieldRule("to", Integer; constraints = [positive()]),
       FieldRule("probability", Real; constraints = [in_range(0.0, 1.0)]),
       FieldRule("discount_rate", Real; constraints = [non_negative()]),
   ]
   ```

3. **Rewrite Engine entity constructors** to use `validate_schema!`:

   For parameterless types (Serial, Asynchronous, Expectation, WorstCase):

   ```julia
   function Serial(d::Dict{String,Any}, e::CompositeException)
       return Serial()  # No fields to validate
   end
   ```

   For simple types (IterationLimit, TimeLimit, AVaR):

   ```julia
   function IterationLimit(d::Dict{String,Any}, e::CompositeException)
       valid = validate_schema!(d, ITERATION_LIMIT_SCHEMA, e; entity_label = "IterationLimit")
       return valid ? IterationLimit(d["num_iterations"]) : nothing
   end
   ```

   For types with cross-field checks (Convergence -- min <= max):

   ```julia
   function Convergence(d::Dict{String,Any}, e::CompositeException)
       valid_internals = __build_convergence_internals_from_dicts!(d, e)
       valid_schema = valid_internals && validate_schema!(d, CONVERGENCE_SCHEMA, e; entity_label = "Convergence")
       valid_content = valid_schema && __validate_convergence_iterations!(d, e)
       return valid_content ? Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"]) : nothing
   end
   ```

4. **Rewrite Scenarios/StochasticProcess entity constructors** similarly.

5. **Remove all replaced functions**:
   - All `__validate_*_keys_types!` for individual entities (not collection-level)
   - All simple content validators replaced by schema constraints
   - All empty `__validate_*_content!`, `__validate_*_consistency!` stubs
   - All empty `__build_*_internals_from_dicts!` stubs
   - The savings in `input-validators.jl` alone should be approximately 200+ lines of removed stubs

6. **Retain custom validators** that cannot be expressed as schemas:
   - `__validate_convergence_iterations!` -- min <= max cross-field check
   - `__validate_convergence_main_key_type!`, `__validate_parallel_scheme_main_key_type!`, etc. -- parent-key validators
   - All `__build_*!` pipeline functions (convergence, stopping_criteria, risk_measure, parallel_scheme)
   - `__validate_scenarios_keys_types!` and `__validate_scenarios_keys_types_before_build!` -- these check built object types
   - Graph validators from ticket-002 -- keep as-is
   - `__validate_sequential_deterministic_load_stage_indexes!` -- collection-level consistency
   - All `__kind_factory!` calls and related infrastructure
   - `__cast_*_internals_from_files!` -- file resolution pipeline

7. **All existing tests must continue to pass**.

### Inputs/Props

- Same as current: `d::Dict{String,Any}`, `e::CompositeException`

### Outputs/Behavior

- Identical to current behavior for all constructors
- Error messages may have slightly different wording but convey the same information

### Error Handling

- Same error types and accumulation pattern as current

## Acceptance Criteria

- [ ] Given a valid IterationLimit dict `{"num_iterations" => 100}`, when `IterationLimit(d, e)` is called, then `IterationLimit(100)` is returned
- [ ] Given an invalid IterationLimit dict `{"num_iterations" => -1}`, when `IterationLimit(d, e)` is called, then `nothing` is returned with an appropriate error
- [ ] Given a valid AVaR dict `{"alpha" => 0.5}`, when `AVaR(d, e)` is called, then `AVaR(0.5)` is returned
- [ ] Given an out-of-range AVaR dict `{"alpha" => 1.5}`, when `AVaR(d, e)` is called, then `nothing` is returned with an appropriate error
- [ ] Given a valid CVaR dict, when `CVaR(d, e)` is called, then both alpha and lambda are validated via schema
- [ ] Given an empty dict, when `Serial(d, e)` is called, then `Serial()` is returned (no fields to validate)
- [ ] Given a valid Node dict, when the graph validator processes it, then schema validation handles keys/types/basic content
- [ ] Given `src/Engines/sddp/input-validators.jl`, when reviewed, then the file is reduced by at least 150 lines (approximately 25 stub functions removed)
- [ ] Given all existing tests, when run, then all pass without modification (or with minimal error message adjustments)
- [ ] Given the 1dtoy example, when the full pipeline runs, then results are identical to pre-migration

## Implementation Guide

### Suggested Approach

1. **Start with the simplest Engine entities** -- parameterless types:
   - Serial, Asynchronous, Expectation, WorstCase: replace 4-step constructor with direct construction (no fields to validate)
   - Remove all their stub functions from `input-validators.jl`
   - Run tests

2. **Migrate simple Engine entities** -- one or two fields:
   - IterationLimit, TimeLimit, AVaR, CVaR, LowerBoundStability
   - Define schemas, rewrite constructors, remove replaced functions
   - Run tests

3. **Migrate Convergence** -- has build step + cross-field check:
   - Define `CONVERGENCE_SCHEMA` for `min_iterations` and `max_iterations`
   - Keep `__build_convergence_internals_from_dicts!` (it builds stopping_criteria)
   - Keep `__validate_convergence_iterations!` (min <= max cross-field check)
   - Run tests

4. **Migrate SDDPPolicyTaskDefinition and SDDPSimulationTaskDefinition**:
   - These have build steps (convergence, risk_measure, parallel_scheme)
   - `SDDPSimulationTaskDefinition` has `num_simulated_series` that can be schema-validated
   - Keep build pipeline functions
   - Run tests

5. **Migrate DeterministicLoadValue and ScenariosData**:
   - Define schemas for simple fields
   - Keep collection-level and cross-entity validators
   - Run tests

6. **Migrate Node and Edge** (from graph module):
   - Be careful: ticket-002 recently implemented these validators, so check the current state
   - Define schemas, rewrite constructors
   - Keep graph-level consistency validators
   - Run tests

7. **Migrate StochasticProcess entities** (Naive, AutoRegressive):
   - These may have more complex validation -- evaluate whether schema is beneficial vs. the existing validator
   - If the validators are mostly stubs, migrate
   - If they have substantial custom logic, keep as-is
   - Run tests

8. **Run the full test suite** after all migrations.

### Key Files to Modify

- `src/Engines/sddp/input-validators.jl` -- add schemas, remove ~25 stub functions and simple validators
- `src/Engines/sddp/input.jl` -- rewrite 12 constructors
- `src/Engines/input-validators.jl` -- add SDDPEngine schema if applicable
- `src/Scenarios/load-validators.jl` -- add `DETERMINISTIC_LOAD_VALUE_SCHEMA`
- `src/Scenarios/load.jl` -- rewrite `DeterministicLoadValue` constructor
- `src/Scenarios/graph-validators.jl` -- add `NODE_SCHEMA`, `EDGE_SCHEMA`
- `src/Scenarios/scenariosdata-validators.jl` -- add `SCENARIOS_SCHEMA`
- `src/Scenarios/scenariosdata.jl` -- rewrite constructor if applicable
- `src/StochasticProcess/naive-validators.jl` -- add schema if applicable
- `src/StochasticProcess/autoregressive-validators.jl` -- add schema if applicable

### Patterns to Follow

- Follow the same patterns established in ticket-004 for the System entities
- Schema const naming: `ENTITY_SCHEMA` (uppercase with underscores)
- Entity label matches the type name: `entity_label = "IterationLimit"`, `entity_label = "AVaR"`
- For types with build steps, keep the build step first, then schema validation

### Pitfalls to Avoid

- The `Convergence` constructor has a build step (`__build_convergence_internals_from_dicts!`) that must run BEFORE schema validation because it builds the `stopping_criteria` field. The schema only validates `min_iterations` and `max_iterations` -- do not try to schema-validate `stopping_criteria`.
- The `SDDPPolicyTaskDefinition` and `SDDPSimulationTaskDefinition` constructors have build steps for all their nested objects. Schema validation applies only after building, and only for the simple fields that were not built.
- The `__kind_factory!` pattern for stopping_criteria, parallel_scheme, risk_measure must remain unchanged -- it depends on the `kind`/`params` dict structure.
- Graph validators were just written in ticket-002. Review them carefully before modifying -- they may already be well-structured enough that schema migration adds no value for the complex validators.
- The `__validate_scenarios_keys_types!` and `__validate_scenarios_keys_types_before_build!` functions check BOTH simple types (Integer) and built types (Graph, InflowScenarios, LoadScenarios). Only the simple types can be schema-validated.

## Testing Requirements

### Unit Tests

- All existing tests in `test/Engines/`, `test/Scenarios/`, `test/StochasticProcess/` should pass
- If error messages change, update test assertions to match

### Integration Tests

- `test/test-study.jl` must pass
- `test/test-main.jl` must pass (full pipeline with 1dtoy example)

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-003 (schema infrastructure), ticket-004 (System entities migrated first -- establishes the pattern)
- **Blocks**: ticket-006 (cleanup depends on both migration tickets completing)

## Effort Estimate

**Points**: 4
**Confidence**: High
