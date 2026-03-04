# Epic 05 Learnings: Enhanced System Elements

## Patterns Established

### Optional System Entity Pattern

- New entity types are added to `SystemData` as required struct fields, NOT as `Union{T,Nothing}` optionals
- Backward compatibility is achieved in `__build_system_internals_from_dicts!` via `haskey(d, "key")` guards: absent key silently defaults to an empty set (`NonControllables(NonControllable[])`)
- This pattern is now established for all three new types; any future entity type in Epic 06+ must follow it
- Implemented in `src/System/systemdata-validators.jl` lines 48-65

### Empty-Set Early Return in `add_system_elements!`

- Every `add_system_elements!(m, ses::NewType)` method begins with `if length(ses) == 0; return nothing; end`
- This is required because JuMP `@variable` and `@expression` macros over an empty `1:0` range produce zero-element arrays, but downstream code that indexes them (e.g., `m[NC_GENERATION][j]`) still references the symbol, and an absent symbol causes a `KeyError` in `__add_load_balance!`
- Implemented for `NonControllables`, `EnergyContracts`, and `PumpingStations` in `src/Engines/sddp/build.jl` lines 91-94, 111-114, 174-178

### Bus Index Map Reuse for Cross-Entity Coupling

- `_build_bus_index_map(entities, ids, field::Symbol)` is general: it maps any `ids` vector (bus ids, hydro ids) to entity positions using any field name
- Pumping stations reuse this same function to build hydro-to-station maps: `pump_source_map = _build_bus_index_map(pumping_entities, hydro_ids, :source_hydro_id)` and `pump_dest_map = _build_bus_index_map(pumping_entities, hydro_ids, :destination_hydro_id)`
- This eliminates the need for a separate `_build_hydro_pump_map` function; the generic helper handles it with no modifications
- All six precomputed maps are in `src/Engines/sddp/build.jl` lines 420-428

### Nested Dict Flattening in Constructors

- `EnergyContract` and `PumpingStation` have nested input objects (`"limits"` and `"flow"` dicts) that are flattened to scalar struct fields at construction time
- The FieldRule schema validates only the flat scalar fields that can be covered by schema; nested dict validation is done manually in the content validator function
- Pattern: validate the nested dict exists and has correct sub-keys in `__validate_*_content!`, then extract flat values in the constructor
- Reference: `src/System/energycontract-validators.jl` lines 76-129, `src/System/pumpingstation-validators.jl` lines 92-145

### Contract Type Routing at Load Balance, Not at Entity Creation

- Import vs. export sign difference is not pre-split into separate entity collections; a single `contract_bus_map` maps all contracts by bus
- The sign is applied inline in `__add_load_balance!` via `contracts_entities[j].contract_type == "import" ? m[CONTRACT_DISPATCH][j] : -m[CONTRACT_DISPATCH][j]`
- This avoids the index-mismatch pitfall that arises when filtering into sub-vectors: the sub-vector index `j` would not correspond to `CONTRACT_DISPATCH[j]` which is indexed over the full entity vector
- Implemented in `src/Engines/sddp/build.jl` lines 479-483

### Scaling: Consumption Coefficient Requires `s_flow / s_gen` Correction

- `PUMP_POWER = consumption * PUMPED_FLOW` (MW = (MW/m3s) \* m3s)
- After scaling: `PUMPED_FLOW_scaled = flow / s_flow`; `PUMP_POWER_scaled = power / s_gen`
- For the expression to hold: `consumption_scaled = consumption * s_flow / s_gen`
- This is counter-intuitive: the consumption coefficient is scaled UP by `s_flow` and DOWN by `s_gen`, not simply divided by one factor
- Correct implementation in `src/Engines/sddp/scaling.jl` line 214: `ps.consumption_mw_per_m3s * s_flow / s_hgen`

### Objective Guard for Optional Entity Types

- When new entity types may have zero entities, the `SDDP.@stageobjective` sum must guard against empty iteration
- Pattern used: `(num_nc > 0 ? sum(...) : 0.0)` and `(num_contracts > 0 ? sum(...) : 0.0)` in `add_system_objective!`
- Pumping stations have no direct objective contribution, so no guard is needed for them
- Implemented in `src/Engines/sddp/build.jl` lines 252-253

### Build Order Dependency for Cross-Entity Validators

- `PumpingStation` constructor requires a resolved `Hydros` object (not the raw dict) for cross-reference validation
- `__build_pumpingstations!` is called only after `__build_hydros!` succeeds: `(valid_buses && valid_hydros) && __build_pumpingstations!(d, d["buses"], d["hydros"], e)`
- This is the first entity in SDDPlab where a constructor takes three context arguments: `PumpingStation(d, buses, hydros, e)`
- Implemented in `src/System/systemdata-validators.jl` lines 60-64

---

## Architectural Decisions

### Decision: Single Bus Map for Contracts (Not Two Filtered Maps)

- Rejected: building `import_contracts_bus_map` and `export_contracts_bus_map` from filtered sub-vectors
- Reason rejected: the sub-vector index `j` is not the same as the position in the original `CONTRACT_DISPATCH` variable (which is indexed over all contracts); this would cause silent wrong-variable indexing
- Chosen: one `contract_bus_map` over all contracts; contract type is checked inline during load balance construction
- Location: `src/Engines/sddp/build.jl` lines 423 and 479-483

### Decision: `SystemData` as a Plain Struct with 7 Required Fields

- Rejected: making new fields `Union{EntitySet,Nothing}` optional at the type level
- Reason rejected: optional typing propagates `nothing` checks throughout all downstream code (build.jl, scaling.jl, save_simulation.jl); breaks type stability; forces callers to handle `nothing` everywhere
- Chosen: `SystemData` always has all 7 fields; empty sets are the representation for "no entities"; backward compat is in the parser, not the type
- Location: `src/System/System.jl` lines 126-134

### Decision: No `HydroRef` Fields on PumpingStation

- Rejected: storing `Ref{Hydro}` for source and destination on the struct (analogous to `bus::Ref{Bus}`)
- Reason rejected: hydro water balance coupling is done through precomputed index maps, not through struct field dereference; adding refs would be unused and add construction complexity
- Chosen: store only `source_hydro_id` and `destination_hydro_id` as integers; maps built from these ids at model-build time
- Location: `src/System/System.jl` lines 83-93

### Decision: `NC_CURTAILMENT` as a JuMP Expression, Not a Variable

- Chosen because curtailment is fully determined by `max_generation - NC_GENERATION`; adding a variable with equality constraint would add both LP rows and variables for no numerical benefit
- This is consistent with how `NET_EXCHANGE`, `HYDRO_GENERATION`, `OUTFLOW`, and `PUMP_POWER` are handled
- Location: `src/Engines/sddp/build.jl` lines 103-105

---

## Files and Structures Created

- `src/System/noncontrollable-validators.jl` -- FieldRule schema and all validator functions for NonControllable; 105 lines
- `src/System/noncontrollable.jl` -- NonControllable and NonControllables constructors and methods; 102 lines
- `src/System/energycontract-validators.jl` -- FieldRule schema and validators including nested limits validation; 177 lines
- `src/System/energycontract.jl` -- EnergyContract and EnergyContracts constructors and methods; 106 lines
- `src/System/pumpingstation-validators.jl` -- FieldRule schema and validators including cross-entity hydro ID validation; 193 lines
- `src/System/pumpingstation.jl` -- PumpingStation and PumpingStations constructors and methods with 4-argument signatures; 108 lines
- `test/System/test-noncontrollable.jl` -- 10 unit test cases covering schema, bounds, bus validation, consistency
- `test/System/test-energycontract.jl` -- unit tests covering import/export types, nested limits, negative price validity
- `test/System/test-pumpingstation.jl` -- unit tests covering cross-entity hydro ID validation, flow bounds, same-source-dest check

---

## Conventions Adopted

### Variable Symbol Registration

- Every new JuMP variable or expression requires a corresponding `const SYMBOL = Symbol("NAME")` in `src/Lab/variables.jl`
- The symbol must also be exported from `src/Lab/Lab.jl`
- New symbols added: `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW`, `PUMP_POWER`

### `add_system_elements!` Call Order in `SystemData` Dispatcher

- Order matters: `PumpingStations` must be added AFTER `Hydros` because `add_hydro_balance!` references `PUMPED_FLOW` which must exist in the model
- Current order in `src/Engines/sddp/build.jl` lines 216-224: buses, lines, thermals, noncontrollables, energycontracts, pumpingstations, hydros
- Note that `add_hydro_balance!` is called separately after all elements; the dispatcher calls `add_system_elements!(m, get_hydros(s))` which creates the hydro variables, then `add_hydro_balance!` is called in the closure

### `apply_scaling` Must Reconstruct All Entity Sets

- `apply_scaling` in `src/Engines/sddp/scaling.jl` constructs a new `SystemData` with all 7 fields
- Any new entity type added to `SystemData` requires a corresponding scaled copy loop in `apply_scaling`
- Missing this causes a compile error (insufficient positional arguments to `SystemData`)
- All three new entity types have scaled copy loops at lines 181-220

### Cost Scale Factor Uses `abs()` for Negative Prices

- Export contract prices are negative (revenue), but the scaling factor must use the absolute value
- `abs(Float64(c.price_per_mwh))` in `compute_scaling_factors` at `src/Engines/sddp/scaling.jl` line 76
- Without `abs()`, a negative price would reduce `max_cost` and potentially cause under-scaling of other cost terms

### Validator Naming Convention for Nested Dicts

- Nested dict validators are named `__validate_ENTITY_FIELDNAME!` (e.g., `__validate_energycontract_limits!`, `__validate_pumpingstation_flow!`)
- These perform all structural and semantic validation of the nested dict inline, including key presence, type checks, and bound checks
- They return `Bool` (not `Union{T,Nothing}`) because they do not produce an output value to pass to the struct constructor

---

## Surprises and Deviations

### EMERGENCY ticket-025b: test-main Hanging

- Expected: guardian could run `TEST_FILTER="test-main"` to verify the full pipeline after ticket-025
- What happened: `test-main` hung for 1h+ during guardian verification of ticket-025, blocking the session
- Root cause (per ticket-025b): `test-main` runs `SDDP.train` on the 1dtoy example with no explicit `iteration_limit`; train runs until convergence which can take very long or hang indefinitely with certain solver states
- Resolution: ticket-025b was inserted as an emergency ticket; the fix added timeout protection and iteration limit caps to `test-main`
- Impact on plan: guardian verification now relies on filtered unit tests (`TEST_FILTER="test-noncontrollable"` etc.) and explicitly avoids `test-main`
- Location of fix: `test/test-main.jl` (modified by ticket-025b implementation)

### Contracts: `limits` Nested Validation Not Covered by FieldRule Schema

- Expected: the FieldRule schema system could handle the nested `limits` dict the same as flat fields
- What happened: the FieldRule system validates only flat `Dict{String,Any}` fields; nested dicts require manual validator functions
- Resolution: `__validate_energycontract_limits!` was written as a manual validator (177 lines in energycontract-validators.jl vs ~13 lines of schema), following the same pattern used for pumping station `flow` dict
- Implication for Epic 06+: any entity with nested dict fields (e.g., stage duration parameters, inner load block definitions) will require manual validators for those nested portions

### `CONFIGURATION_KEYS` in systemdata-validators.jl Was NOT Extended

- Expected: the `CONFIGURATION_KEYS` array at the top of `src/System/systemdata-validators.jl` would need to include `"noncontrollables"`, `"energycontracts"`, `"pumpingstations"`
- What happened: these three keys are optional and handled via `haskey` guards in `__build_system_internals_from_dicts!`; they are intentionally NOT in `CONFIGURATION_KEYS` (which only lists required keys that `__validate_system_keys_types!` enforces)
- Result: existing system files without the new sections continue to load without modification -- backward compatibility is fully preserved
- `CONFIGURATION_KEYS` remains `["buses", "lines", "hydros", "thermals"]` at `src/System/systemdata-validators.jl` line 3

### `_build_bus_index_map` is More General Than Its Name Implies

- The function was named for bus mapping but works for any entity-to-id mapping
- For pumping stations, it is called twice with `hydro_ids` as the second argument, which is semantically "hydro position mapping" but uses the same code path
- This generality was not planned in the ticket; it emerged during implementation as the cleanest solution
- Future entity types that couple to non-bus entities (e.g., thermal groups, reservoir networks) can reuse this function identically

---

## Recommendations for Future Epics

### For Epic 06: Subproblem Structure (stage time duration, inner load blocks, inflow non-negativity)

- When adding stage time duration (`hours_per_stage`): it will need to scale the load in `__add_load_balance!` (currently loads from `get_load` are in MWh-equivalent units; with variable duration, the conversion factor changes per stage) -- this is a deeper change than adding a new entity type; budget more than 3 points
- When adding inner load blocks: these would require indexing variables over `(hydro, block)` or `(bus, block)` instead of just `(hydro,)` or `(bus,)`; this changes the shape of all arrays in `__add_load_balance!` and `add_system_objective!`; the bus index map pattern needs extension to also index by block
- Inflow non-negativity: the simplest approach is a lower bound on `INFLOW` variable; but `INFLOW` is currently set by `JuMP.fix.(m[INFLOW], ω)` in the `SDDP.parameterize` callback -- a `fix` on a variable with a bound constraint will cause infeasibility if the SAA sample is negative; the correct approach is to add a slack variable and modify the parameterize callback
- For any new quantity that involves multiplying by a per-stage duration factor: add a `duration_scale` synthetic symbol to `ScalingConfig` similar to `FLOW_SCALE` and `COST_SCALE`

### General Patterns for New System Entity Types

- Follow the 9-step recipe established in Epic 05: (1) symbol in variables.jl, (2) export in Lab.jl, (3) struct in System.jl, (4) entity-validators.jl file, (5) entity.jl file, (6) include in System.jl, (7) haskey optional handling in systemdata-validators.jl, (8) accessor in systemdata.jl, (9) update build.jl + scaling.jl + save_simulation.jl
- For entities with cross-entity references (like pumping stations referencing hydros): add the resolved entity collection as an extra constructor argument; call `__build_ENTITY!` only AFTER its dependencies are built in `__build_system_internals_from_dicts!`
- For entities with no objective contribution (like pumping stations): skip the `add_system_objective!` update entirely; do not add a zero-contribution term just for symmetry
- Never add tests to existing large test files; always create a new file under `test/System/` or `test/Engines/sddp/` -- SIGABRT risk is real and unexplained
- Use `TEST_FILTER="test-ENTITYNAME"` (120000ms timeout) to verify new unit tests; never use `TEST_FILTER="test-main"` for verification

### Cross-Cutting Concerns for All Future Modifications to build.jl

- `__generate_subproblem_builder` precomputes all entity lists and maps before the closure; any new entity requiring bus-level or hydro-level maps must be added to the precomputation block at lines 411-428 of `src/Engines/sddp/build.jl`
- `__add_load_balance!` signature grows with each new entity that contributes to load balance; currently at 14 parameters; consider refactoring into a context struct if this grows beyond 18 parameters
- `apply_scaling` in `src/Engines/sddp/scaling.jl` must include a scaled copy loop for every field of `SystemData`; the compile error from a missing field is immediate and unambiguous -- treat this as a checklist item
