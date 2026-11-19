# ticket-027 Add Pumping Stations System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify hydro water balance integration, bus index maps, and type stability)

## Context

### Background

Pumping stations transfer water from a source reservoir to a destination reservoir while consuming electrical power. They couple to hydro water balances (source hydro loses water, destination hydro gains water) and to the bus load balance (power consumption at the connected bus). There is no direct cost in the objective -- the cost of pumping is implicitly captured through energy consumption at the bus.

This is the most complex ticket in Epic 05 because it introduces cross-entity coupling: pumping stations reference hydro entities by ID and modify the existing hydro water balance constraint. This requires cross-entity validation (source_hydro_id and destination_hydro_id must reference valid hydro IDs) and modification of the existing `add_hydro_balance!` function.

### Relation to Epic

This is the third and final ticket in Epic 05. It builds on the entity addition pattern established by tickets 025 and 026. The unique challenge is that pumping stations interact with an existing entity type (hydros) rather than being self-contained. This means modifying `add_hydro_balance!` and precomputing source/destination hydro maps for efficient lookup.

### Current State

After tickets 025 and 026 are complete:

- `SystemData` has 6 fields: `buses`, `lines`, `hydros`, `thermals`, `noncontrollables`, `energycontracts`
- The optional entity key pattern is well established
- `_build_bus_index_map` is the standard approach for precomputing entity-to-bus lookups
- `add_hydro_balance!` in `src/Engines/sddp/build.jl` (lines 146-161) currently enforces:
  ```
  v[n].out == v[n].in - outflow[n] + inflow[n] + sum(outflow[j] for downstream(j) == n)
  ```
  This needs to add `- pumped_flow[j]` for source hydros and `+ pumped_flow[j]` for destination hydros.

The hydro balance uses `downstream()` to find cascade inflows. Pumping stations are NOT part of the cascade -- they are independent entities that reference hydros by ID. The modification must add pumping terms without disturbing the existing cascade topology logic.

## Specification

### Requirements

1. **Entity struct**: `PumpingStation <: SystemEntity` with fields: `id`, `name`, `bus_id`, `source_hydro_id`, `destination_hydro_id`, `consumption_mw_per_m3s`, `min_m3s`, `max_m3s`, `bus` (Ref{Bus})
2. **Entity set struct**: `PumpingStations <: SystemEntitySet` with field: `entities::Vector{PumpingStation}`
3. **FieldRule schema**: `PUMPING_STATION_SCHEMA` validating `id` (positive Integer), `name` (non-empty alphanumeric String), `bus_id` (Integer), `source_hydro_id` (Integer), `destination_hydro_id` (Integer), `consumption_mw_per_m3s` (positive Real), `flow` (Dict with `min_m3s` non-negative Real and `max_m3s` positive Real)
4. **Constructor pipeline**: `PumpingStation(d, buses, hydros, e)` -- note the extra `hydros` argument for cross-entity validation of source/destination hydro IDs
5. **SystemData integration**: Add optional `pumpingstations` field to `SystemData` (7th field), with backward-compatible default of empty `PumpingStations(PumpingStation[])`
6. **JuMP variables**: `PUMPED_FLOW` variable bounded by `[min_m3s, max_m3s]` per station, `PUMP_POWER` expression = `consumption_mw_per_m3s * PUMPED_FLOW`
7. **Hydro balance modification**: For source hydros: `-PUMPED_FLOW[j]`; for destination hydros: `+PUMPED_FLOW[j]`
8. **Load balance**: `-PUMP_POWER[j]` at connected bus (power consumed)
9. **Objective**: No direct contribution (cost is implicit through energy consumption)
10. **Scaling**: `PUMPED_FLOW` scales with the flow factor (same as `TURBINED_FLOW`/`SPILLAGE`); `PUMP_POWER` scales with the generation factor; `consumption_mw_per_m3s` scales with `s_gen / s_flow` (so that `consumption_scaled * flow_scaled = consumption * s_gen/s_flow * flow/s_flow = consumption * flow * s_gen/s_flow^2`... careful -- see Pitfalls)
11. **Simulation output**: `PUMPED_FLOW` and `PUMP_POWER` in unscale and output pipeline

### Inputs/Props

Data model (Dict constructor input):

```json
{
  "id": 1,
  "name": "SANTA_CECILIA",
  "bus_id": 1,
  "source_hydro_id": 5,
  "destination_hydro_id": 10,
  "consumption_mw_per_m3s": 0.85,
  "flow": {
    "min_m3s": 0.0,
    "max_m3s": 150.0
  }
}
```

The `flow` object is nested in the input Dict but flattened during construction: `min_m3s` and `max_m3s` are stored as flat fields on the struct.

### Outputs/Behavior

- `add_system_elements!(m, PumpingStations)` creates `PUMPED_FLOW` variable and `PUMP_POWER` expression
- `add_hydro_balance!` is extended to include pumping flow terms
- Pumping power consumption appears as negative load balance contribution at the station's bus
- No direct objective contribution
- Simulation output includes `operation_pumping` file with `PUMPED_FLOW` and `PUMP_POWER` columns

### Error Handling

- Missing or invalid fields: `CompositeException` accumulation via `validate_schema!`
- Invalid `bus_id`: `AssertionError` pushed to exception, constructor returns `nothing`
- Invalid `source_hydro_id` (not found in hydros): `AssertionError` pushed, constructor returns `nothing`
- Invalid `destination_hydro_id` (not found in hydros): `AssertionError` pushed, constructor returns `nothing`
- `source_hydro_id == destination_hydro_id`: `AssertionError` (cannot pump from/to same reservoir)
- `min_m3s > max_m3s`: `AssertionError` in content validation
- `consumption_mw_per_m3s <= 0`: caught by `positive()` constraint in schema
- Empty pumpingstations section: valid (backward compatibility)
- Missing pumpingstations key entirely: valid -- defaults to empty set

## Acceptance Criteria

- [ ] Given a valid system with hydros, when a PumpingStation referencing valid hydro IDs is constructed, then the entity is created with correct field values
- [ ] Given a PumpingStation with `source_hydro_id` not found in hydros, when the constructor is called, then it returns `nothing` with `AssertionError`
- [ ] Given a PumpingStation with `source_hydro_id == destination_hydro_id`, when the constructor is called, then it returns `nothing` with `AssertionError`
- [ ] Given a system.jsonc WITHOUT a `pumpingstations` key, when `SystemData` is constructed, then construction succeeds with empty `PumpingStations` (backward compatibility)
- [ ] Given a system with PumpingStations, when the SDDP model is built, then `PUMPED_FLOW` variables exist with bounds `[min_m3s, max_m3s]`
- [ ] Given a system with PumpingStations, when the SDDP model is built, then `PUMP_POWER` expressions exist as `consumption_mw_per_m3s * PUMPED_FLOW`
- [ ] Given a PumpingStation with source_hydro at position n, when the hydro balance is constructed, then `-PUMPED_FLOW[j]` appears in hydro n's water balance
- [ ] Given a PumpingStation with destination_hydro at position n, when the hydro balance is constructed, then `+PUMPED_FLOW[j]` appears in hydro n's water balance
- [ ] Given a PumpingStation at bus n, when the load balance is constructed, then `-PUMP_POWER[j]` appears in bus n's load balance (power consumed)
- [ ] Given AutoScaling is enabled, when scaling is applied, then `PUMPED_FLOW` bounds scale with the flow factor and `consumption_mw_per_m3s` is adjusted correctly
- [ ] Given a simulation is complete, when results are saved, then `operation_pumping` output includes `PUMPED_FLOW` and `PUMP_POWER` with correct unscaling
- [ ] All existing tests pass (no regression), including hydro balance tests

## Implementation Guide

### Suggested Approach

1. **Add variable symbols** to `src/Lab/variables.jl`:

   ```julia
   # Pumping Stations
   PUMPED_FLOW = Symbol("PUMPED_FLOW")
   PUMP_POWER = Symbol("PUMP_POWER")
   ```

2. **Create entity struct** in `src/System/System.jl`:

   ```julia
   struct PumpingStation <: SystemEntity
       id::Integer
       name::String
       bus_id::Integer
       source_hydro_id::Integer
       destination_hydro_id::Integer
       consumption_mw_per_m3s::Real
       min_m3s::Real
       max_m3s::Real
       bus::Ref{Bus}
   end

   struct PumpingStations <: SystemEntitySet
       entities::Vector{PumpingStation}
   end
   ```

3. **Create `src/System/pumpingstation-validators.jl`**:
   - `PUMPING_STATION_SCHEMA` with FieldRules for `id`, `name`, `bus_id`, `source_hydro_id`, `destination_hydro_id`, `consumption_mw_per_m3s`
   - Note: `flow` is nested Dict -- validate manually in content validation (same pattern as contract `limits`)
   - `__validate_pumpingstation_content!`: validate bus_id, source_hydro_id and destination_hydro_id exist in hydros, source != destination, flatten flow, min <= max
   - `__validate_pumpingstations_consistency!`: unique ids, unique names

4. **Create `src/System/pumpingstation.jl`** following thermal.jl pattern:
   - `PumpingStation(d, buses, hydros, e)` constructor -- note extra `hydros` arg for cross-entity validation
   - `PumpingStations(d, buses, hydros, e)` constructor
   - Standard methods: `get_id`, `get_params`, `get_ids`, `length`
   - Helper functions: `__build_pumpingstation_entities!`, `__build_pumpingstations!`, `__cast_pumpingstations_internals_from_files!`

5. **Include new files** in `src/System/System.jl` (before systemdata-validators.jl):

   ```julia
   include("pumpingstation-validators.jl")
   include("pumpingstation.jl")
   ```

6. **Update `src/System/systemdata-validators.jl`**:
   - Add `"pumpingstations"` as optional key
   - In `__build_system_internals_from_dicts!`: `__build_pumpingstations!` must be called AFTER `__build_hydros!` succeeds, since pumping stations cross-reference hydros:
     ```julia
     valid_pumping = (valid_buses && valid_hydros) && __build_pumpingstations!(d, d["buses"], d["hydros"], e)
     ```

7. **Update `src/System/systemdata.jl`**:
   - Update `SystemData` constructor to pass 7 fields
   - Add `get_pumpingstations(s)` and `get_pumpingstations_entities(s)` accessors
   - Export new types and accessors

8. **Update `src/Engines/sddp/build.jl`**:

   a. Add `add_system_elements!(m, ses::PumpingStations)`:

   ```julia
   function add_system_elements!(m::JuMP.Model, ses::PumpingStations)
       num_stations = length(ses)
       m[PUMPED_FLOW] = JuMP.@variable(
           m, [n = 1:num_stations], base_name = String(PUMPED_FLOW)
       )
       for n in 1:num_stations
           JuMP.set_lower_bound(m[PUMPED_FLOW][n], ses.entities[n].min_m3s)
           JuMP.set_upper_bound(m[PUMPED_FLOW][n], ses.entities[n].max_m3s)
       end
       m[PUMP_POWER] = JuMP.@expression(
           m, [n = 1:num_stations],
           ses.entities[n].consumption_mw_per_m3s * m[PUMPED_FLOW][n]
       )
       return nothing
   end
   ```

   b. Update `add_system_elements!(m, s::SystemData)` to call it

   c. **Modify `add_hydro_balance!`** to accept pumping station data and add pumping terms. Two approaches:

   **Preferred approach** -- precompute source/destination hydro maps:

   ```julia
   function _build_hydro_pump_map(
       stations::AbstractVector, hydro_ids::Vector{<:Integer}, hydro_field::Symbol
   )::Dict{Int,Vector{Int}}
       map = Dict{Int,Vector{Int}}()
       for (j, station) in enumerate(stations)
           hid = getfield(station, hydro_field)
           for (n, hydro_id) in enumerate(hydro_ids)
               if hid == hydro_id
                   indices = get!(map, n, Int[])
                   push!(indices, j)
               end
           end
       end
       return map
   end
   ```

   This is essentially the same as `_build_bus_index_map` but mapping hydro positions instead of bus positions. You can reuse `_build_bus_index_map` directly by passing hydro IDs as the second argument and `:source_hydro_id` or `:destination_hydro_id` as the field.

   Then update `add_hydro_balance!` to:

   ```julia
   function add_hydro_balance!(m::JuMP.Model, hydros::Hydros,
       pump_source_map::Dict{Int,Vector{Int}},
       pump_dest_map::Dict{Int,Vector{Int}})
       num_hydros = length(hydros)
       m[HYDRO_BALANCE] = JuMP.@constraint(
           m, [n = 1:num_hydros],
           m[STORED_VOLUME][n].out ==
               m[STORED_VOLUME][n].in - m[OUTFLOW][n] + m[INFLOW][n] +
               sum(m[OUTFLOW][j] for j in 1:num_hydros if
                   downstream(hydros.entities[j].id, hydros) == hydros.entities[n]) -
               sum(m[PUMPED_FLOW][j] for j in get(pump_source_map, n, Int[])) +
               sum(m[PUMPED_FLOW][j] for j in get(pump_dest_map, n, Int[]))
       )
       return nothing
   end
   ```

   **IMPORTANT**: Keep backward compatibility for the case with no pumping stations. When `PumpingStations` is empty, `pump_source_map` and `pump_dest_map` are empty Dicts, and the `sum(... for j in Int[])` evaluates to 0 -- JuMP handles this correctly.

   d. Add `pumping_bus_map` in `__generate_subproblem_builder` and update `__add_load_balance!` to include `-PUMP_POWER[j]` at bus

   e. Update `add_system_elements!(m, s::SystemData)` call to `add_hydro_balance!` to pass the pump maps

9. **Update `src/Engines/sddp/scaling.jl`**:

   Scaling analysis for pumping stations:
   - `PUMPED_FLOW` is in flow units (m3/s) -- scales with `s_flow` (same as `TURBINED_FLOW`, `SPILLAGE`)
   - `PUMP_POWER` = `consumption * PUMPED_FLOW` is in MW (generation units) -- scales with `s_gen`
   - For dimensional consistency: `PUMP_POWER_scaled = consumption_scaled * PUMPED_FLOW_scaled` must hold
   - `s_gen = consumption_scaled * s_flow` => `consumption_scaled = consumption * s_gen / s_flow`
   - In `apply_scaling`: `min_m3s / s_flow`, `max_m3s / s_flow`, `consumption_mw_per_m3s * s_flow / s_gen`
     Wait, let's verify: `PUMP_POWER_scaled[j] = consumption_scaled * flow_scaled = (consumption * s_flow / s_gen) * (flow / s_flow) = consumption * flow / s_gen`. But we want `PUMP_POWER_scaled = consumption * flow / s_gen` (i.e., `PUMP_POWER / s_gen`). Check: `PUMP_POWER = consumption * flow` (MW), and `PUMP_POWER_scaled = PUMP_POWER / s_gen`. So `consumption_scaled * flow_scaled = consumption * flow / s_gen`. With `flow_scaled = flow / s_flow`: `consumption_scaled = (consumption * flow / s_gen) / (flow / s_flow) = consumption * s_flow / s_gen`.
   - **Final**: `consumption_scaled = consumption * s_flow / s_gen`

   - In `compute_scaling_factors`: add `factors[PUMPED_FLOW] = s_hydro` (same as flow scale)
   - In `no_scaling_config`: add `PUMPED_FLOW => DEFAULT_SCALING_FACTOR`

10. **Update `src/Engines/sddp/save_simulation.jl`**:
    - In `_get_variable_unscale_factor`: add `PUMPED_FLOW` => `s_flow`, `PUMP_POWER` => `s_gen`
    - In `__write_simulation_results`: add `"operation_pumping" => [PUMPED_FLOW, PUMP_POWER]`

### Key Files to Modify

- `src/Lab/variables.jl` -- add PUMPED_FLOW, PUMP_POWER symbols
- `src/System/System.jl` -- add struct definitions, includes, exports
- `src/System/pumpingstation-validators.jl` -- **new file**
- `src/System/pumpingstation.jl` -- **new file**
- `src/System/systemdata-validators.jl` -- add pumpingstations as optional key
- `src/System/systemdata.jl` -- update constructor, add accessors
- `src/Engines/sddp/build.jl` -- add_system_elements!, modify add_hydro_balance!, load balance, bus/hydro maps
- `src/Engines/sddp/scaling.jl` -- compute_scaling_factors, no_scaling_config, apply_scaling
- `src/Engines/sddp/save_simulation.jl` -- unscale factor, write results

### Patterns to Follow

- **Bus index map for hydros**: Reuse `_build_bus_index_map` by passing hydro IDs (from `get_ids(get_hydros(system))`) as the "bus_ids" argument and `:source_hydro_id` / `:destination_hydro_id` as the field. This gives `Dict{Int,Vector{Int}}` mapping hydro position to station indices -- exactly what's needed for the hydro balance.
- **Entity file pair**: Same `pumpingstation.jl` + `pumpingstation-validators.jl` convention.
- **Cross-entity constructor**: Similar to how `Line(d, buses, e)` takes `buses` for cross-reference validation, `PumpingStation(d, buses, hydros, e)` takes both `buses` and `hydros`.

### Pitfalls to Avoid

- **Modifying `add_hydro_balance!` signature**: This function is called from `add_system_elements!(m, s::SystemData)`. The pump maps must be computed in `__generate_subproblem_builder` (not inside `add_system_elements!`) because maps are precomputed once and reused per node. Pass the maps through the call chain.
- **Hydro ID vs hydro position**: Hydro IDs are user-assigned (e.g., 5, 10). Hydro positions are 1-based indices into `hydros.entities`. The `_build_bus_index_map` pattern maps positions, not IDs. Make sure `source_hydro_id` and `destination_hydro_id` are resolved to positions during validation, and the maps use position-based indexing.
- **`sum()` with empty iterator**: JuMP's `sum(expr for j in Int[])` works correctly (returns 0), but verify this in tests. The hydro balance must remain correct when no pumping stations exist.
- **Scaling chain**: The `consumption_mw_per_m3s` scaling is `consumption * s_flow / s_gen` (not `consumption / s_gen`). This is because `PUMP_POWER_scaled = consumption_scaled * PUMPED_FLOW_scaled`, and both sides must be dimensionally consistent with the load balance (which is in generation-scaled units).
- **SystemData constructor sites**: After adding `pumpingstations` as the 7th field, ALL `SystemData` construction sites must be updated: the `SystemData(d, e)` constructor, and `apply_scaling` in scaling.jl. Missing any site will cause a compile error.
- **Build order dependency**: `__build_pumpingstations!` must be called after `__build_hydros!` succeeds in `__build_system_internals_from_dicts!`, because pumping station validation requires resolved `Hydros` object.
- **Test file isolation**: Create `test/System/test-pumpingstation.jl` -- do NOT modify existing test files.

## Testing Requirements

### Unit Tests

Create `test/System/test-pumpingstation.jl`:

- `pumpingstation-valid`: construct with valid Dict referencing existing hydro IDs, verify type
- `pumpingstation-invalid-bus-id`: nonexistent bus, verify returns `nothing`
- `pumpingstation-invalid-source-hydro-id`: nonexistent source hydro, verify returns `nothing` with `AssertionError`
- `pumpingstation-invalid-destination-hydro-id`: nonexistent destination hydro, verify returns `nothing` with `AssertionError`
- `pumpingstation-same-source-destination`: source == destination, verify returns `nothing` with `AssertionError`
- `pumpingstation-missing-flow`: remove `flow` key, verify returns `nothing`
- `pumpingstation-min-greater-than-max-flow`: `min_m3s > max_m3s`, verify returns `nothing`
- `pumpingstation-negative-consumption`: consumption <= 0, verify returns `nothing`
- `pumpingstation-zero-flow-valid`: min=0, max=0, verify succeeds (edge case: deactivated station)
- `pumpingstations-unique-ids`: duplicate ids fail
- `pumpingstations-unique-names`: duplicate names fail

### Integration Tests

- `systemdata-without-pumpingstations`: verify existing system loads with empty PumpingStations
- `systemdata-with-pumpingstations`: construct SystemData dict with pumpingstations section referencing valid hydros

### Hydro Balance Tests

Create `test/Engines/sddp/test-pumping-balance.jl`:

- `hydro-balance-no-pumping`: verify hydro balance unchanged when PumpingStations is empty (regression test)
- `hydro-balance-with-pumping`: construct a minimal 2-hydro system with one pumping station, build the JuMP model, verify that the hydro balance constraint for the source hydro includes `-PUMPED_FLOW[1]` and the destination hydro includes `+PUMPED_FLOW[1]`

### E2E Tests (if applicable)

After all three Epic 05 tickets are complete, create a comprehensive pipeline test with a system including NonControllables, EnergyContracts, and PumpingStations together.

## Dependencies

- **Blocked By**: ticket-026
- **Blocks**: None (within epic-05); epic-06 depends on epic-05 completion

## Effort Estimate

**Points**: 4
**Confidence**: High
