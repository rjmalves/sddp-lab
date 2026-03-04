# ticket-026 Add Energy Contracts System Element

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify type stability, bus index map integration, and scaling system updates)

## Context

### Background

Energy contracts represent agreements to buy (import) or sell (export) electricity with external systems. Each contract has a `type` field (`"import"` or `"export"`), a price per MWh, and dispatch bounds. Import contracts add power to the bus load balance; export contracts remove power. The objective contribution is `price_per_mwh * dispatch` where import prices are positive (cost) and export prices are typically negative (revenue).

This ticket follows the same entity addition pattern established by ticket-025 (NonControllable). The key difference is the `type` field which determines the sign of the load balance contribution, and the price which enters the objective directly.

### Relation to Epic

This is the second ticket in Epic 05. It depends on ticket-025 because ticket-025 establishes the pattern for adding a new optional entity to `SystemData` (including backward compatibility handling). Once ticket-025 is complete, the `SystemData` struct will already have 5 fields and the optional entity pattern will be established, making this ticket follow the same approach.

### Current State

After ticket-025 is complete:

- `SystemData` has 5 fields: `buses`, `lines`, `hydros`, `thermals`, `noncontrollables`
- The optional entity key pattern (handling missing JSONC keys with empty set defaults) is established
- `__add_load_balance!` accepts bus index maps as arguments
- `add_system_objective!` sums costs from all entity types
- The system entity file pair convention (`entity.jl` + `entity-validators.jl`) is well established

The contract entity is structurally similar to `NonControllable` but introduces:

1. A `type` field with enum-like validation (`"import"` or `"export"`)
2. Nested `limits` object with `min_mw` and `max_mw`
3. Sign-dependent load balance contribution based on contract type
4. Direct price contribution to the objective (not a penalty/regularization)

## Specification

### Requirements

1. **Entity struct**: `EnergyContract <: SystemEntity` with fields: `id`, `name`, `bus_id`, `contract_type` (String -- `"import"` or `"export"`), `price_per_mwh`, `min_mw`, `max_mw`, `bus` (Ref{Bus})
2. **Entity set struct**: `EnergyContracts <: SystemEntitySet` with field: `entities::Vector{EnergyContract}`
3. **FieldRule schema**: `ENERGY_CONTRACT_SCHEMA` validating `id` (positive Integer), `name` (non-empty alphanumeric String), `bus_id` (Integer), `type` (String), `price_per_mwh` (Real -- can be negative for export revenue), `limits` (Dict containing `min_mw` and `max_mw`)
4. **Constructor pipeline**: `EnergyContract(d, buses, e)` using `validate_schema!` + cross-field validation for `type in ["import", "export"]`, `min_mw <= max_mw`, and valid `bus_id`
5. **SystemData integration**: Add optional `energycontracts` field to `SystemData`, with backward-compatible default of empty `EnergyContracts(EnergyContract[])`
6. **JuMP variables**: `CONTRACT_DISPATCH` variable bounded by `[min_mw, max_mw]` per contract
7. **Load balance**: For import contracts: `+CONTRACT_DISPATCH[j]` at bus; for export contracts: `-CONTRACT_DISPATCH[j]` at bus. Use two separate bus maps: `contract_import_bus_map` and `contract_export_bus_map`
8. **Objective**: `price_per_mwh * CONTRACT_DISPATCH[n]` per contract (import positive cost, export negative = revenue)
9. **Scaling**: CONTRACT_DISPATCH scales with the generation factor; price_per_mwh scales with `1/s_cost`
10. **Simulation output**: CONTRACT_DISPATCH in unscale and output pipeline

### Inputs/Props

Data model (Dict constructor input):

```json
{
  "id": 1,
  "name": "ITAIPU_BR",
  "bus_id": 1,
  "type": "import",
  "price_per_mwh": 50.0,
  "limits": {
    "min_mw": 0.0,
    "max_mw": 6000.0
  }
}
```

The `type` field must be exactly `"import"` or `"export"`. The `limits` object is flattened during construction: `min_mw` and `max_mw` are extracted from `d["limits"]["min_mw"]` and `d["limits"]["max_mw"]` and stored as flat fields on the struct.

### Outputs/Behavior

- `add_system_elements!(m, EnergyContracts)` creates `CONTRACT_DISPATCH` variables with bounds
- Import contracts contribute positively to load balance (power enters system); export contracts contribute negatively (power leaves system)
- Contract prices appear in the stage objective
- Simulation output includes `operation_contracts` file with `CONTRACT_DISPATCH` column

### Error Handling

- Missing or invalid fields: `CompositeException` accumulation via `validate_schema!`
- Invalid `bus_id`: `AssertionError` pushed to exception, constructor returns `nothing`
- Invalid `type` (not "import" or "export"): `AssertionError` in content validation
- `min_mw > max_mw`: `AssertionError` in content validation
- `min_mw < 0`: caught by `non_negative()` in limits schema validation
- Empty energycontracts section: valid (backward compatibility)
- Missing energycontracts key entirely: valid -- defaults to empty set

## Acceptance Criteria

- [ ] Given a valid system.jsonc with an `energycontracts` section containing import contracts, when `SystemData` is constructed, then `EnergyContract` entities are created with `contract_type == "import"` and correct field values
- [ ] Given a valid system.jsonc with export contracts, when `SystemData` is constructed, then entities have `contract_type == "export"` and correct field values
- [ ] Given a system.jsonc WITHOUT an `energycontracts` key, when `SystemData` is constructed, then construction succeeds with an empty `EnergyContracts` set (backward compatibility)
- [ ] Given an EnergyContract with `type` value other than `"import"` or `"export"`, when the constructor is called, then it returns `nothing` and pushes an `AssertionError`
- [ ] Given an EnergyContract with `min_mw > max_mw`, when the constructor is called, then it returns `nothing` and pushes an `AssertionError`
- [ ] Given a system with import EnergyContracts at bus n, when the load balance is constructed, then `+CONTRACT_DISPATCH[j]` appears for each import contract j at bus n
- [ ] Given a system with export EnergyContracts at bus n, when the load balance is constructed, then `-CONTRACT_DISPATCH[j]` appears for each export contract j at bus n
- [ ] Given a system with EnergyContracts, when the objective is constructed, then `price_per_mwh * CONTRACT_DISPATCH[n]` appears for each contract
- [ ] Given AutoScaling is enabled, when scaling is applied, then `CONTRACT_DISPATCH` bounds scale with the generation factor and `price_per_mwh` scales with `1/s_cost`
- [ ] Given a simulation is complete, when results are saved, then `operation_contracts` output includes `CONTRACT_DISPATCH` with correct unscaling
- [ ] All existing tests pass (no regression)

## Implementation Guide

### Suggested Approach

1. **Add variable symbols** to `src/Lab/variables.jl`:

   ```julia
   # Energy Contracts
   CONTRACT_DISPATCH = Symbol("CONTRACT_DISPATCH")
   ```

2. **Create entity struct** in `src/System/System.jl`:

   ```julia
   struct EnergyContract <: SystemEntity
       id::Integer
       name::String
       bus_id::Integer
       contract_type::String   # "import" or "export"
       price_per_mwh::Real
       min_mw::Real
       max_mw::Real
       bus::Ref{Bus}
   end

   struct EnergyContracts <: SystemEntitySet
       entities::Vector{EnergyContract}
   end
   ```

3. **Create `src/System/energycontract-validators.jl`** following the thermal-validators pattern:
   - `ENERGY_CONTRACT_SCHEMA` with FieldRules for `id`, `name`, `bus_id`, `type`, `price_per_mwh`
   - Note: `limits` is a nested Dict, so validate it manually in content validation (the FieldRule system handles flat fields)
   - `__validate_energycontract_content!`: validate bus_id, type enum, flatten limits, min <= max
   - `__validate_energycontracts_consistency!`: unique ids, unique names

4. **Create `src/System/energycontract.jl`** following the thermal.jl pattern:
   - `EnergyContract(d, buses, e)` constructor -- must flatten `d["limits"]["min_mw"]` and `d["limits"]["max_mw"]` into the struct
   - `EnergyContracts(d, buses, e)` constructor
   - Standard methods: `get_id`, `get_params`, `get_ids`, `length`
   - Helper functions: `__build_energycontract_entities!`, `__build_energycontracts!`, `__cast_energycontracts_internals_from_files!`

5. **Include new files** in `src/System/System.jl` (before systemdata-validators.jl):

   ```julia
   include("energycontract-validators.jl")
   include("energycontract.jl")
   ```

6. **Update `src/System/systemdata-validators.jl`**: Add `"energycontracts"` as optional key (same pattern as noncontrollables in ticket-025).

7. **Update `src/System/systemdata.jl`**:
   - Update `SystemData` constructor to pass 6 fields
   - Add `get_energycontracts(s)` and `get_energycontracts_entities(s)` accessors
   - Export new types and accessors

8. **Update `src/Engines/sddp/build.jl`**:
   - Add `add_system_elements!(m, ses::EnergyContracts)`:
     ```julia
     function add_system_elements!(m::JuMP.Model, ses::EnergyContracts)
         num_contracts = length(ses)
         m[CONTRACT_DISPATCH] = JuMP.@variable(
             m, [n = 1:num_contracts], base_name = String(CONTRACT_DISPATCH)
         )
         for n in 1:num_contracts
             JuMP.set_lower_bound(m[CONTRACT_DISPATCH][n], ses.entities[n].min_mw)
             JuMP.set_upper_bound(m[CONTRACT_DISPATCH][n], ses.entities[n].max_mw)
         end
         return nothing
     end
     ```
   - Update `add_system_elements!(m, s::SystemData)` to call `add_system_elements!(m, get_energycontracts(s))`
   - Add two bus maps in `__generate_subproblem_builder`:
     ```julia
     import_contracts = filter(c -> c.contract_type == "import", contracts_entities)
     export_contracts = filter(c -> c.contract_type == "export", contracts_entities)
     contract_import_bus_map = _build_bus_index_map(import_contracts, bus_ids, :bus_id)
     contract_export_bus_map = _build_bus_index_map(export_contracts, bus_ids, :bus_id)
     ```
     **IMPORTANT**: The indices in these maps must reference positions in the FULL `contracts_entities` vector, not the filtered sub-vectors. Alternatively, use a single bus map and check `contract_type` inside the load balance loop. The simpler approach: build one `contract_bus_map` for all contracts, and in load balance, iterate all contracts at the bus, adding `+CONTRACT_DISPATCH[j]` for imports and `-CONTRACT_DISPATCH[j]` for exports based on `contract_type`.
   - Update `__add_load_balance!` to include contract terms
   - Update `add_system_objective!`:
     ```julia
     sum(contracts[n].price_per_mwh * m[CONTRACT_DISPATCH][n] for n in 1:num_contracts)
     ```

9. **Update `src/Engines/sddp/scaling.jl`**:
   - In `compute_scaling_factors`: include `EnergyContract.max_mw` in `all_gen` collection; set `factors[CONTRACT_DISPATCH]` to generation scale
   - In `no_scaling_config`: add `CONTRACT_DISPATCH => DEFAULT_SCALING_FACTOR`
   - In `apply_scaling`: create scaled contracts with `min_mw / s_hgen`, `max_mw / s_hgen`, `price_per_mwh / s_cost`

10. **Update `src/Engines/sddp/save_simulation.jl`**:
    - In `_get_variable_unscale_factor`: add `CONTRACT_DISPATCH` => `s_gen`
    - In `__write_simulation_results`: add `"operation_contracts" => [CONTRACT_DISPATCH]` to output map

### Key Files to Modify

- `src/Lab/variables.jl` -- add CONTRACT_DISPATCH symbol
- `src/System/System.jl` -- add struct definitions, includes, exports
- `src/System/energycontract-validators.jl` -- **new file**
- `src/System/energycontract.jl` -- **new file**
- `src/System/systemdata-validators.jl` -- add energycontracts as optional key
- `src/System/systemdata.jl` -- update constructor, add accessors
- `src/Engines/sddp/build.jl` -- add_system_elements!, load balance, objective, bus map
- `src/Engines/sddp/scaling.jl` -- compute_scaling_factors, no_scaling_config, apply_scaling
- `src/Engines/sddp/save_simulation.jl` -- unscale factor, write results

### Patterns to Follow

- **Thermal entity pattern**: Same as ticket-025. `EnergyContract` is structurally similar to `Thermal` with bus reference and scalar fields.
- **Nested dict flattening**: The `limits` object is nested in the input Dict but flattened in the struct. Validate `d["limits"]` is a `Dict{String,Any}` in the constructor, then extract `min_mw` and `max_mw` before calling the struct constructor.
- **Import/export bus maps**: Follow the `line_source_map` / `line_target_map` pattern from `build.jl` lines 357-358. Lines have two bus maps for source and target. Contracts similarly need separation of import vs export for correct load balance signs.

### Pitfalls to Avoid

- **Import/export bus map indices**: If you filter contracts into import/export sub-vectors before building bus maps, the indices in the maps will reference positions in the sub-vector, not the original `contracts_entities` vector. This means `CONTRACT_DISPATCH[j]` would index the wrong contract. Either: (a) build one map and check type inline, or (b) build two separate bus maps using the full entity vector with a type filter.
- **SystemData construction sites**: After adding `energycontracts` as the 6th field, update `apply_scaling` (which constructs a new `SystemData`) and the `SystemData(d, e)` constructor.
- **Negative prices are valid**: Export contracts typically have negative `price_per_mwh` (revenue). Do NOT add a `non_negative()` constraint on `price_per_mwh`. The FieldRule should just be `FieldRule("price_per_mwh", Real)`.
- **Test file isolation**: Create `test/System/test-energycontract.jl` -- do NOT modify existing test files.

## Testing Requirements

### Unit Tests

Create `test/System/test-energycontract.jl`:

- `energycontract-valid-import`: construct import contract with valid Dict, verify type and `contract_type == "import"`
- `energycontract-valid-export`: construct export contract, verify `contract_type == "export"`
- `energycontract-invalid-type`: set `type` to `"bilateral"`, verify returns `nothing` with error
- `energycontract-invalid-bus-id`: set `bus_id` to nonexistent bus, verify returns `nothing`
- `energycontract-missing-limits`: remove `limits` key, verify returns `nothing`
- `energycontract-min-greater-than-max`: set `min_mw > max_mw`, verify returns `nothing` with error
- `energycontract-negative-price-valid`: export with negative price, verify succeeds
- `energycontract-zero-bounds-valid`: both min_mw and max_mw = 0.0, verify succeeds
- `energycontracts-unique-ids`: duplicate ids fail consistency validation
- `energycontracts-unique-names`: duplicate names fail consistency validation

### Integration Tests

- `systemdata-without-energycontracts`: verify existing system.jsonc loads with empty EnergyContracts (backward compatibility)
- `systemdata-with-energycontracts`: construct SystemData dict with energycontracts section, verify entities are created

### E2E Tests (if applicable)

Deferred to after all three epic-05 tickets. A full pipeline test will be created with a system that includes all new entities.

## Dependencies

- **Blocked By**: ticket-025
- **Blocks**: ticket-027

## Effort Estimate

**Points**: 3
**Confidence**: High
