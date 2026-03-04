# ticket-004 Migrate System Entities to Schema Validation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (mechanical migration of existing validation logic to schema tables)

## Context

### Background

Ticket-003 introduced the `FieldRule` schema infrastructure in `src/Utils/schema.jl`. This ticket uses that infrastructure to migrate all System module entities (Bus, Buses, Line, Lines, Hydro, Hydros, Thermal, Thermals, SystemData) from hand-written validator functions to declarative schema tables. The System module is the largest source of validation boilerplate (approximately 700 lines across `bus-validators.jl`, `line-validators.jl`, `hydro-validators.jl`, `thermal-validators.jl`, and `systemdata-validators.jl`).

### Relation to Epic

This is the fourth ticket in Epic 01. It performs the first batch of schema migration (System entities), demonstrating that the schema infrastructure works correctly with the real codebase. It depends on ticket-003 (schema infrastructure). Ticket-005 will migrate the remaining entities (Engine, Scenarios, StochasticProcess).

### Current State

Each System entity follows the 4-step pattern with dedicated validator functions. Taking `Bus` as the representative example:

**`src/System/bus-validators.jl`** (124 lines) contains:

- `__validate_buses_main_key_type!` -- checks `d["buses"]` exists and is `Dict{String,Any}`
- `__validate_bus_keys_types!` -- checks `["id", "name", "deficit_cost"]` exist and are `[Integer, String, Real]`
- `__validate_buses_keys_types!` -- checks `["entities"]` exists and is `Vector{Bus}`
- `__validate_buses_keys_types_before_build!` -- checks `["entities"]` exists and is `Vector{Dict{String,Any}}`
- `__validate_bus_id!` -- checks `d["id"] > 0`
- `__validate_bus_name!` -- checks non-empty and regex match
- `__validate_bus_deficit_cost!` -- checks `d["deficit_cost"] > 0`
- `__validate_bus_content!` -- calls the three above
- `__validate_buses_content!` -- returns true
- `__validate_bus_consistency!` -- returns true
- `__validate_buses_unique_ids!` -- checks unique bus IDs
- `__validate_buses_unique_names!` -- checks unique bus names
- `__validate_buses_consistency!` -- calls unique checks
- `__build_bus_internals_from_dicts!` -- returns true
- `__build_buses_internals_from_dicts!` -- calls `__build_bus_entities!`

Similar patterns exist for Line (154 lines), Hydro (266 lines), and Thermal (170 lines).

**`src/System/bus.jl`** has the constructor:

```julia
function Bus(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_bus_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_bus_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_bus_content!(d, e)
    valid_consistency = valid_content && __validate_bus_consistency!(d, e)
    return valid_consistency ? Bus(d["id"], d["name"], d["deficit_cost"]) : nothing
end
```

**Cross-entity dependencies**: Thermal, Line, and Hydro constructors receive `buses::Buses` as an extra argument for foreign-key validation (e.g., `__validate_thermal_bus_id` checks that `d["bus_id"]` exists in `get_ids(buses)`). Hydro also builds a topology graph via `__build_hydro_topology!`.

## Specification

### Requirements

1. **Define schema constants** for each entity in their respective validator files:

   **Bus schema** (replaces `__validate_bus_keys_types!` + `__validate_bus_id!` + `__validate_bus_name!` + `__validate_bus_deficit_cost!` + `__validate_bus_content!`):

   ```julia
   const BUS_SCHEMA = [
       FieldRule("id", Integer; constraints = [positive()]),
       FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
       FieldRule("deficit_cost", Real; constraints = [positive()]),
   ]
   ```

   **Thermal schema** (replaces keys_types + simple content validators):

   ```julia
   const THERMAL_SCHEMA = [
       FieldRule("id", Integer; constraints = [positive()]),
       FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
       FieldRule("bus_id", Integer),  # cross-entity check done in custom validator
       FieldRule("min_generation", Real; constraints = [non_negative()]),
       FieldRule("max_generation", Real; constraints = [non_negative()]),
       FieldRule("cost", Real; constraints = [non_negative()]),
   ]
   ```

   **Line schema**:

   ```julia
   const LINE_SCHEMA = [
       FieldRule("id", Integer; constraints = [positive()]),
       FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
       FieldRule("bus_from", Integer),  # cross-entity check done in custom validator
       FieldRule("bus_to", Integer),    # cross-entity check done in custom validator
       FieldRule("reactance", Real; constraints = [positive()]),
       FieldRule("capacity", Real; constraints = [non_negative()]),
   ]
   ```

   **Hydro schema**:

   ```julia
   const HYDRO_SCHEMA = [
       FieldRule("id", Integer; constraints = [positive()]),
       FieldRule("downstream_id", Integer; constraints = [non_negative()]),
       FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
       FieldRule("bus_id", Integer),  # cross-entity check done in custom validator
       FieldRule("productivity", Real; constraints = [non_negative()]),
       FieldRule("initial_storage", Real; constraints = [non_negative()]),
       FieldRule("min_storage", Real; constraints = [non_negative()]),
       FieldRule("max_storage", Real; constraints = [non_negative()]),
       FieldRule("min_generation", Real; constraints = [non_negative()]),
       FieldRule("max_generation", Real; constraints = [non_negative()]),
       FieldRule("spillage_penalty", Real; constraints = [non_negative()]),
   ]
   ```

2. **Rewrite entity constructors** to use `validate_schema!`:

   **Bus constructor** (before):

   ```julia
   function Bus(d::Dict{String,Any}, e::CompositeException)
       valid_internals = __build_bus_internals_from_dicts!(d, e)
       valid_keys_types = valid_internals && __validate_bus_keys_types!(d, e)
       valid_content = valid_keys_types && __validate_bus_content!(d, e)
       valid_consistency = valid_content && __validate_bus_consistency!(d, e)
       return valid_consistency ? Bus(d["id"], d["name"], d["deficit_cost"]) : nothing
   end
   ```

   **Bus constructor** (after):

   ```julia
   function Bus(d::Dict{String,Any}, e::CompositeException)
       valid = validate_schema!(d, BUS_SCHEMA, e; entity_label = "Bus $(get(d, "id", "?"))")
       return valid ? Bus(d["id"], d["name"], d["deficit_cost"]) : nothing
   end
   ```

   **Thermal constructor** (after -- note custom validator for cross-entity and min/max):

   ```julia
   function Thermal(d::Dict{String,Any}, buses::Buses, e::CompositeException)
       valid_schema = validate_schema!(d, THERMAL_SCHEMA, e; entity_label = "Thermal $(get(d, "id", "?"))")
       bus_ref = valid_schema ? __validate_thermal_bus_id(d, buses, e) : nothing
       valid_content = bus_ref !== nothing
       valid_generation = valid_schema && __validate_thermal_generation(d, e)
       valid = valid_content && valid_generation
       return valid ? Thermal(d["id"], d["name"], d["bus_id"], d["min_generation"], d["max_generation"], d["cost"], bus_ref) : nothing
   end
   ```

3. **Retain custom validators** that cannot be expressed as simple field constraints:
   - `__validate_thermal_bus_id` / `__validate_hydro_bus_id` / `__validate_line_bus_from` / `__validate_line_bus_to` -- cross-entity foreign-key checks
   - `__validate_thermal_generation` / `__validate_hydro_generation` -- min <= max cross-field checks
   - `__validate_hydro_storage` -- initial_storage in [min_storage, max_storage] check
   - `__validate_hydros_consistency!` -- topology DAG check
   - All `__validate_*s_unique_ids!` / `__validate_*s_unique_names!` -- collection-level uniqueness checks
   - All `__build_*_entities!` / `__build_*_internals_from_dicts!` -- build pipeline functions

4. **Remove the following functions** (replaced by schema validation):
   - All `__validate_*_keys_types!` per-entity functions (Bus, Line, Hydro, Thermal singular)
   - All simple per-field content validators: `__validate_bus_id!`, `__validate_bus_name!`, `__validate_bus_deficit_cost!`, `__validate_bus_content!`, `__validate_thermal_id`, `__validate_thermal_name`, `__validate_thermal_cost`, `__validate_thermal_content!` (the cross-entity part stays), `__validate_hydro_id`, `__validate_hydro_downstream_id`, `__validate_hydro_name`, `__validate_hydro_productivity`, `__validate_hydro_spillage_penalty`, `__validate_hydro_content!` (cross-entity part stays), similar for Line
   - All stub functions that just `return true`: `__validate_bus_consistency!`, `__validate_buses_content!`, `__validate_thermal_consistency!`, `__validate_thermals_content!`, `__validate_hydro_consistency!`, `__validate_hydros_content!`, etc.
   - All `__build_*_internals_from_dicts!` stubs that just `return true` (Bus, Thermal, Hydro, Line singular)

5. **Keep the collection-level validators and build pipeline** unchanged:
   - `__validate_buses_main_key_type!`, `__validate_buses_keys_types!`, `__validate_buses_keys_types_before_build!` -- these check the `entities` key in the parent dict
   - `__validate_buses_consistency!` -- collection-level uniqueness
   - `__build_buses_internals_from_dicts!`, `__build_bus_entities!` -- build pipeline
   - `__cast_*_internals_from_files!` -- file resolution pipeline
   - Same pattern for all other entities

6. **All existing tests must continue to pass** without modification. The schema migration must be behavior-preserving: same errors, same error messages (or equivalent), same return values.

### Inputs/Props

- Same as current: `d::Dict{String,Any}`, `e::CompositeException`, and optionally `buses::Buses` for cross-entity validators

### Outputs/Behavior

- Identical to current behavior: constructors return the typed object or `nothing`, errors are pushed to `CompositeException`
- Error messages may change slightly in wording (e.g., "Bus ? - id (-1) must be positive" vs "Bus id (-1) must be positive") but must convey the same information

### Error Handling

- Same error types: `ErrorException` for missing keys and type failures, `AssertionError` for constraint violations
- Same error accumulation: all applicable errors are collected, not short-circuited

## Acceptance Criteria

- [ ] Given a valid Bus dict, when `Bus(d, e)` is called, then the result is identical to the pre-migration behavior
- [ ] Given an invalid Bus dict (negative id, empty name), when `Bus(d, e)` is called, then `nothing` is returned and errors are pushed to `e`
- [ ] Given a valid Thermal dict with a valid bus reference, when `Thermal(d, buses, e)` is called, then the result is a `Thermal` with the correct `bus_ref`
- [ ] Given a Thermal dict with an invalid `bus_id` (not in buses), when `Thermal(d, buses, e)` is called, then `nothing` is returned with an appropriate error
- [ ] Given a valid Hydro dict, when `Hydro(d, buses, e)` is called, then the min/max storage and generation cross-field checks still work correctly
- [ ] Given a set of Hydros with a cyclic topology, when `Hydros(d, buses, e)` is called, then the DAG validation still catches the cycle
- [ ] Given the full 1dtoy example, when the pipeline runs end-to-end, then results are identical to pre-migration
- [ ] Given `bus-validators.jl`, when the file is reviewed, then `__validate_bus_keys_types!`, `__validate_bus_id!`, `__validate_bus_name!`, `__validate_bus_deficit_cost!`, `__validate_bus_content!`, `__validate_bus_consistency!`, and `__build_bus_internals_from_dicts!` no longer exist
- [ ] Given `bus-validators.jl`, when the file is reviewed, then a `const BUS_SCHEMA` is defined using `FieldRule` entries
- [ ] Given all existing tests (`test/System/*`, `test/test-study.jl`, `test/test-main.jl`), when run, then all pass without modification

## Implementation Guide

### Suggested Approach

1. **Start with Bus** (simplest entity, no cross-entity dependencies):
   - Define `const BUS_SCHEMA` in `bus-validators.jl`
   - Rewrite `Bus(d, e)` constructor in `bus.jl` to use `validate_schema!`
   - Remove replaced functions from `bus-validators.jl`
   - Run tests -- verify all pass

2. **Migrate Thermal** (introduces cross-entity pattern):
   - Define `const THERMAL_SCHEMA` in `thermal-validators.jl`
   - Rewrite `Thermal(d, buses, e)` to use `validate_schema!` for simple fields, then call custom `__validate_thermal_bus_id` and `__validate_thermal_generation` for cross-entity and cross-field checks
   - Remove replaced functions
   - Run tests

3. **Migrate Line** (similar to Thermal with bus_from/bus_to):
   - Define `const LINE_SCHEMA`
   - Rewrite constructor, keeping cross-entity bus checks
   - Remove replaced functions
   - Run tests

4. **Migrate Hydro** (most complex: bus reference, topology, storage/generation cross-field):
   - Define `const HYDRO_SCHEMA`
   - Rewrite constructor, keeping `__validate_hydro_bus_id`, `__validate_hydro_storage`, `__validate_hydro_generation`, and topology building
   - Remove replaced functions
   - Run tests

5. **Run the full test suite** after all migrations to verify end-to-end behavior.

### Key Files to Modify

- `src/System/bus-validators.jl` -- add `BUS_SCHEMA`, remove replaced functions
- `src/System/bus.jl` -- rewrite `Bus(d, e)` constructor
- `src/System/thermal-validators.jl` -- add `THERMAL_SCHEMA`, remove replaced functions, keep cross-entity validators
- `src/System/thermal.jl` -- rewrite `Thermal(d, buses, e)` constructor
- `src/System/line-validators.jl` -- add `LINE_SCHEMA`, remove replaced functions, keep cross-entity validators
- `src/System/line.jl` -- rewrite `Line(d, buses, e)` constructor
- `src/System/hydro-validators.jl` -- add `HYDRO_SCHEMA`, remove replaced functions, keep cross-entity/topology validators
- `src/System/hydro.jl` -- rewrite `Hydro(d, buses, e)` constructor

### Patterns to Follow

- The schema const should be named `ENTITY_SCHEMA` (e.g., `BUS_SCHEMA`, `THERMAL_SCHEMA`)
- Entity label in `validate_schema!` should use `"EntityName $(get(d, "id", "?"))"` to match the existing error message style
- Cross-entity validators remain as explicit functions -- do NOT try to express them as `FieldConstraint` predicates
- Cross-field validators (min <= max) remain as explicit functions

### Pitfalls to Avoid

- The `Buses(d, e)` constructor validates the collection level (`__validate_buses_keys_types!`, `__validate_buses_consistency!`) -- do NOT migrate this to schema. Only the singular `Bus(d, e)` constructor gets the schema treatment.
- The `__build_buses_internals_from_dicts!` function and `__build_bus_entities!` are the build pipeline -- they must remain unchanged.
- The `__validate_buses_keys_types_before_build!` checks that `d["entities"]` is `Vector{Dict{String,Any}}` before building -- this must remain unchanged.
- The `__cast_*_internals_from_files!` functions (file resolution) are completely separate from validation -- leave them unchanged.
- Error messages will change slightly (schema produces `"Bus ? - id (-1) must be positive"` vs the old `"Bus id (-1) must be positive"`). If existing tests assert exact error messages, they may need adjustment. Check test assertions before modifying.
- The Hydro constructor calls `__validate_hydro_content!` which returns `Ref{Bus}` or `nothing` -- ensure the rewritten constructor still produces the `bus_ref` correctly.

## Testing Requirements

### Unit Tests

- All existing tests in `test/System/` should pass without modification (or with minimal error message adjustments)
- If error messages change, update test assertions to match the new format

### Integration Tests

- `test/test-study.jl` must pass
- `test/test-main.jl` must pass (full pipeline with 1dtoy example)

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-003 (schema infrastructure must exist first)
- **Blocks**: ticket-006 (schema migration must be proven on System entities before migrating Engine/Scenarios)

## Effort Estimate

**Points**: 4
**Confidence**: High
