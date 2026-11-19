# ticket-025 Add Non-Controllable Generation System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability and integration with existing System module patterns)

## Context

### Background

SDDPlab currently models four system entities: buses, lines, hydros, and thermals. Modern power systems include intermittent renewable generation (wind, solar, small run-of-river hydros) that cannot be dispatched upward -- the solver can only curtail below the available output. This ticket adds a `NonControllable` entity type with deterministic availability (fixed at `max_generation` per entity). Stochastic availability integration with the SAA pipeline is deferred to a future epic.

The non-controllable source has:

- A generation decision variable `g_nc` bounded by `[0, max_generation]`
- A curtailment expression `curtailment = max_generation - g_nc` (derived, not a separate variable)
- A small regularization `curtailment_cost` in the objective to incentivize using all available generation
- Connection to exactly one bus via `bus_id`
- No state variables (unlike hydro `STORED_VOLUME`)

### Relation to Epic

This is the first ticket in Epic 05 (Enhanced System Elements). It establishes the pattern for adding new system elements that subsequent tickets (026, 027) will follow. The entity must integrate with the System module, the SDDP subproblem builder, the load balance constraint, the scaling system, the variable units registry, and the simulation output pipeline.

### Current State

- Entity types defined as structs in `src/System/System.jl` (lines 16-86)
- Each entity has a file pair: `entity.jl` (constructors, methods) + `entity-validators.jl` (schema, validators)
- `SystemData` struct has 4 fields: `buses`, `lines`, `hydros`, `thermals` (line 81-86)
- `add_system_elements!(m, system)` in `src/Engines/sddp/build.jl` dispatches to per-type methods (lines 163-170)
- `__add_load_balance!` uses precomputed `_build_bus_index_map` for O(1) lookups (lines 382-410)
- `add_system_objective!` sums costs from all entities (lines 172-194)
- `compute_scaling_factors` and `apply_scaling` in `src/Engines/sddp/scaling.jl` handle LP rescaling
- `_get_variable_unscale_factor` in `src/Engines/sddp/save_simulation.jl` maps symbols to unscale factors
- Variable symbols defined in `src/Lab/variables.jl`

## Specification

### Requirements

1. **Entity struct**: `NonControllable <: SystemEntity` with fields: `id`, `name`, `bus_id`, `max_generation`, `curtailment_cost`, `bus` (Ref{Bus})
2. **Entity set struct**: `NonControllables <: SystemEntitySet` with field: `entities::Vector{NonControllable}`
3. **FieldRule schema**: `NONCONTROLLABLE_SCHEMA` validating `id` (positive Integer), `name` (non-empty alphanumeric String), `bus_id` (Integer), `max_generation` (non-negative Real), `curtailment_cost` (non-negative Real)
4. **Constructor pipeline**: `NonControllable(d, buses, e)` using `validate_schema!` + `__validate_noncontrollable_content!` (bus_id validation)
5. **SystemData integration**: Add optional `noncontrollables` field to `SystemData`, with backward-compatible constructor that defaults to empty `NonControllables(NonControllable[])` when key is absent
6. **JuMP variables**: `NC_GENERATION` variable bounded by `[0, max_generation]`, `NC_CURTAILMENT` expression = `max_generation - NC_GENERATION`
7. **Load balance**: `+NC_GENERATION[j]` for non-controllables at bus n
8. **Objective**: `+curtailment_cost * NC_CURTAILMENT[n]` per entity (penalize curtailment)
9. **Scaling**: NC_GENERATION scales with the generation factor (same as HYDRO_GENERATION/THERMAL_GENERATION/DEFICIT)
10. **Simulation output**: NC_GENERATION and NC_CURTAILMENT in `_get_variable_unscale_factor` and `__write_simulation_results`

### Inputs/Props

Data model (Dict constructor input):

```json
{
  "id": 1,
  "name": "WIND_FARM_NE",
  "bus_id": 1,
  "max_generation": 500.0,
  "curtailment_cost": 0.005
}
```

The `curtailment_cost` field is required (no global default system in SDDPlab currently). Typical values: 0.001-0.01 $/MWh.

### Outputs/Behavior

- `add_system_elements!(m, NonControllables)` creates `NC_GENERATION` variable and `NC_CURTAILMENT` expression
- Non-controllables appear in load balance as generation at their bus
- Curtailment cost appears in the stage objective
- Simulation output includes `operation_noncontrollables` file with `NC_GENERATION` and `NC_CURTAILMENT` columns

### Error Handling

- Missing or invalid fields: `CompositeException` accumulation via `validate_schema!` (same pattern as Thermal)
- Invalid `bus_id`: `AssertionError` pushed to exception, constructor returns `nothing`
- `max_generation < 0`: caught by `non_negative()` constraint in schema
- `curtailment_cost < 0`: caught by `non_negative()` constraint in schema
- Empty noncontrollables section in system.jsonc: valid (backward compatibility) -- creates `NonControllables(NonControllable[])`
- Missing noncontrollables key entirely: valid -- defaults to empty set

## Acceptance Criteria

- [ ] Given a valid system.jsonc with a `noncontrollables` section, when `SystemData` is constructed, then `NonControllable` entities are created with correct field values
- [ ] Given a system.jsonc WITHOUT a `noncontrollables` key, when `SystemData` is constructed, then construction succeeds with an empty `NonControllables` set (backward compatibility)
- [ ] Given a NonControllable with invalid `bus_id`, when the constructor is called, then it returns `nothing` and pushes an `AssertionError` to the exception
- [ ] Given a NonControllable with negative `curtailment_cost`, when the constructor is called, then it returns `nothing` and pushes an error to the exception
- [ ] Given a system with NonControllables, when the SDDP model is built, then `NC_GENERATION` variables exist with correct bounds `[0, max_generation]`
- [ ] Given a system with NonControllables, when the SDDP model is built, then `NC_CURTAILMENT` expressions exist as `max_generation - NC_GENERATION`
- [ ] Given a system with NonControllables at bus n, when the load balance is constructed, then `+NC_GENERATION[j]` appears for each NonControllable j at bus n
- [ ] Given a system with NonControllables, when the objective is constructed, then `curtailment_cost * NC_CURTAILMENT[n]` appears in the stage objective
- [ ] Given AutoScaling is enabled, when scaling is applied, then `NC_GENERATION` scales with the generation factor and `curtailment_cost` is adjusted by `s_gen / (s_cost * s_gen)` = `1/s_cost`
- [ ] Given a simulation is complete, when results are saved, then `operation_noncontrollables` output includes `NC_GENERATION` and `NC_CURTAILMENT` with correct unscaling
- [ ] All existing tests pass (no regression from adding the optional noncontrollables field)

## Implementation Guide

### Suggested Approach

1. **Add variable symbols** to `src/Lab/variables.jl`:

   ```julia
   # Non-Controllables
   NC_GENERATION = Symbol("NC_GENERATION")
   NC_CURTAILMENT = Symbol("NC_CURTAILMENT")
   ```

2. **Create entity struct** in `src/System/System.jl` (after Thermal struct, before SystemEntitySet section):

   ```julia
   struct NonControllable <: SystemEntity
       id::Integer
       name::String
       bus_id::Integer
       max_generation::Real
       curtailment_cost::Real
       bus::Ref{Bus}
   end

   struct NonControllables <: SystemEntitySet
       entities::Vector{NonControllable}
   end
   ```

3. **Update `SystemData`** to include the new field:

   ```julia
   struct SystemData <: InputModule
       buses::Buses
       lines::Lines
       hydros::Hydros
       thermals::Thermals
       noncontrollables::NonControllables
   end
   ```

4. **Create `src/System/noncontrollable-validators.jl`** following the pattern of `thermal-validators.jl`:
   - `NONCONTROLLABLE_SCHEMA` with FieldRules
   - `__validate_noncontrollables_main_key_type!`
   - `__validate_noncontrollables_keys_types!`
   - `__validate_noncontrollables_keys_types_before_build!`
   - `__validate_noncontrollable_content!` (bus_id cross-validation)
   - `__validate_noncontrollables_consistency!` (unique ids, unique names)
   - `__build_noncontrollables_internals_from_dicts!`

5. **Create `src/System/noncontrollable.jl`** following the pattern of `thermal.jl`:
   - `NonControllable(d, buses, e)` constructor
   - `NonControllables(d, buses, e)` constructor
   - `get_id`, `get_params`, `get_ids`, `length` methods
   - `__build_noncontrollable_entities!`, `__build_noncontrollables!`, `__cast_noncontrollables_internals_from_files!`

6. **Include new files** in `src/System/System.jl` (before `systemdata-validators.jl`):

   ```julia
   include("noncontrollable-validators.jl")
   include("noncontrollable.jl")
   ```

7. **Update `src/System/systemdata-validators.jl`**:
   - Add `"noncontrollables"` to `CONFIGURATION_KEYS` and corresponding types
   - Make it optional: if key is absent, create empty `NonControllables(NonControllable[])`
   - Update `__build_system_internals_from_dicts!` to call `__build_noncontrollables!`
   - Update `__cast_system_internals_from_files!` to call `__cast_noncontrollables_internals_from_files!`

8. **Update `src/System/systemdata.jl`**:
   - Update `SystemData(d, e)` constructor to pass 5 fields
   - Add `get_noncontrollables(s)` and `get_noncontrollables_entities(s)` accessor methods
   - Export new types and accessors

9. **Update `src/Engines/sddp/build.jl`**:
   - Add `add_system_elements!(m, ses::NonControllables)` method
   - Update `add_system_elements!(m, s::SystemData)` to call it
   - Add `noncontrollable_bus_map` in `__generate_subproblem_builder` (precomputed bus index map)
   - Update `__add_load_balance!` signature and body to include `+NC_GENERATION[j]` terms
   - Update `add_system_objective!` to include `curtailment_cost * NC_CURTAILMENT[n]` terms

10. **Update `src/Engines/sddp/scaling.jl`**:
    - In `compute_scaling_factors`: include `NonControllable.max_generation` in `all_gen` collection; set `factors[NC_GENERATION]` to same generation scale factor
    - In `no_scaling_config`: add `NC_GENERATION => DEFAULT_SCALING_FACTOR`
    - In `apply_scaling`: create scaled `NonControllable` entities with `max_generation / s_hgen` and `curtailment_cost / s_cost`

11. **Update `src/Engines/sddp/save_simulation.jl`**:
    - In `_get_variable_unscale_factor`: add `NC_GENERATION` => `s_gen`, `NC_CURTAILMENT` => `s_gen`
    - In `__write_simulation_results`: add `"operation_noncontrollables" => [NC_GENERATION, NC_CURTAILMENT]` to `map_variable_output` and corresponding entries in `map_variable_entities`

### Key Files to Modify

- `src/Lab/variables.jl` -- add NC_GENERATION, NC_CURTAILMENT symbols
- `src/System/System.jl` -- add struct definitions, includes, exports
- `src/System/noncontrollable-validators.jl` -- **new file**
- `src/System/noncontrollable.jl` -- **new file**
- `src/System/systemdata-validators.jl` -- add noncontrollables to configuration keys (optional)
- `src/System/systemdata.jl` -- update constructor, add accessors
- `src/Engines/sddp/build.jl` -- add_system_elements!, load balance, objective, bus map
- `src/Engines/sddp/scaling.jl` -- compute_scaling_factors, no_scaling_config, apply_scaling
- `src/Engines/sddp/save_simulation.jl` -- unscale factor, write results

### Patterns to Follow

- **Thermal entity pattern**: The `NonControllable` entity is structurally closest to `Thermal` (both have `bus_id`, simple scalar fields, bus reference). Follow `thermal.jl` / `thermal-validators.jl` exactly for constructor pipeline, validator structure, and method signatures.
- **Bus index map pattern**: Follow the existing `_build_bus_index_map` usage in `__generate_subproblem_builder` (lines 355-358 of `build.jl`) for `noncontrollable_bus_map`.
- **Optional system entity**: Since existing datasets do not have noncontrollables, the `SystemData` constructor must handle the missing key gracefully. Use `haskey(d, "noncontrollables")` with fallback to empty set.

### Pitfalls to Avoid

- **Breaking backward compatibility**: The `SystemData` struct gains a new field. Every place that constructs `SystemData` directly must be updated. The `apply_scaling` function constructs a new `SystemData` and must include the noncontrollables field.
- **Missing bus map argument**: `__add_load_balance!` signature must be extended with `noncontrollable_bus_map`. All call sites must be updated.
- **Curtailment cost scaling**: The curtailment cost must be scaled by `1/s_cost` (not `1/(s_cost * s_gen)`), because the curtailment expression already includes the generation scale factor. The objective term is `curtailment_cost * (max_gen_scaled - NC_GEN_scaled)`, which in unscaled terms becomes `(curtailment_cost / s_cost) * s_gen * (max_gen/s_gen - NC_GEN/s_gen) = (curtailment_cost / s_cost) * (max_gen - NC_GEN)`. Alternatively, look at how `spillage_penalty` scaling works in `apply_scaling` -- `h.spillage_penalty * s_flow / (s_cost * s_hgen)` -- because spillage is in flow units. For NC, the curtailment is in generation units (MW), so the scaling of curtailment_cost should match the thermal cost pattern: `curtailment_cost / s_cost`.
- **Test file isolation**: Create a NEW test file `test/System/test-noncontrollable.jl` -- NEVER add tests to existing large test files (SIGABRTs observed).
- **`SDDP.parameterize` untouched**: This ticket does NOT modify the SAA/parameterize pipeline. Non-controllable availability is deterministic (fixed at `max_generation`).

## Testing Requirements

### Unit Tests

Create `test/System/test-noncontrollable.jl`:

- `noncontrollable-valid`: construct with valid Dict, verify type is `NonControllable`
- `noncontrollable-invalid-bus-id`: set `bus_id` to nonexistent bus, verify returns `nothing`
- `noncontrollable-missing-name`: remove `"name"` key, verify returns `nothing`
- `noncontrollable-negative-max-generation`: set negative, verify returns `nothing` with error
- `noncontrollable-negative-curtailment-cost`: set negative, verify returns `nothing` with error
- `noncontrollable-zero-max-generation`: set to 0.0, verify succeeds (valid edge case)
- `noncontrollable-boundary-id-zero-fails`: id=0 fails positive() constraint
- `noncontrollable-boundary-id-one-passes`: id=1 passes
- `noncontrollables-unique-ids`: duplicate ids fail consistency validation
- `noncontrollables-unique-names`: duplicate names fail consistency validation

### Integration Tests

Create `test/System/test-noncontrollable-integration.jl` or add a small testset to `test/test-main.jl` (in a new testset block, not modifying existing ones):

- `systemdata-without-noncontrollables`: verify existing system.jsonc loads correctly with empty NonControllables (backward compatibility)
- `systemdata-with-noncontrollables`: construct SystemData dict with noncontrollables section, verify entities are created

### E2E Tests (if applicable)

A full pipeline test (build + train + simulate) with a system including NonControllables would validate the entire integration but may be deferred to after all three epic-05 tickets are done, to avoid creating a separate example case for each ticket.

## Dependencies

- **Blocked By**: ticket-024 (Epic 04 complete)
- **Blocks**: ticket-026

## Effort Estimate

**Points**: 3
**Confidence**: High
