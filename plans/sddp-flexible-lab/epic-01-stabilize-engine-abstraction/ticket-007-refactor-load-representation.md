# ticket-007 Refactor Load Representation to Node-Based Graph

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (structural refactor of Julia types and validation, no SDDP algorithm knowledge needed)

## Context

### Background

The `abstract-engine` branch has multiple TODO comments indicating that the load representation needs to be refactored. Currently, `DeterministicLoad` uses a `stage_index::Integer` field to map load values to stages, and the `__add_load_balance!` function in `src/Engines/sddp/build.jl` directly looks up load by `(bus_id, node_integer)` without going through the graph's node structure. This coupling to raw integer indices bypasses the graph abstraction and will not generalize to cyclic graphs or graphs with non-sequential node IDs.

### Relation to Epic

This is the seventh ticket in Epic 01. It resolves the most impactful TODO in the codebase -- the load representation -- which is referenced in three separate files. It depends on ticket-002 (graph validators) because the refactored load must reference validated graph nodes. It also depends on tickets 003-006 (validation simplification) because the load validators should use the new schema infrastructure.

### Current State

**`src/Scenarios/load.jl`** defines `DeterministicLoadValue` with fields:

```julia
struct DeterministicLoadValue
    bus_id::Integer
    stage_index::Integer  # <-- this indexes into stages, not graph nodes
    value::Real
end
```

**`src/Scenarios/Scenarios.jl`** has the TODO comment:

```julia
# TODO - change to be an abstract scenario entity when
# the load is also an stochastic process
```

And the `get_load` function:

```julia
function get_load(bus_id::Integer, stage_index::Integer, scenarios::ScenariosData)::Real
    return __get_load(bus_id, stage_index, scenarios.load)
end
```

**`src/Engines/sddp/build.jl`** has the `__add_load_balance!` function with TODO:

```julia
# TODO - this will change once we have a proper load representation
function __add_load_balance!(m::JuMP.Model, files::Vector{InputModule}, node::Integer)
    ...
    m[LOAD_BALANCE] = JuMP.@constraint(
        m, [n = 1:num_buses],
        ... == get_load(bus_ids[n], node, scenarios)
    )
end
```

And in the subproblem builder:

```julia
# TODO - this will change once we have a proper load representation
# as an stochastic process
__add_load_balance!(m, files, node)
```

**`load.csv`** (1dtoy example) contains columns: `bus_id`, `stage_index`, `value`.

**After tickets 003-006**: The `DeterministicLoadValue` constructor should already be using schema validation (via `DETERMINISTIC_LOAD_VALUE_SCHEMA` from ticket-005). The load validators in `src/Scenarios/load-validators.jl` should already have some functions replaced by schema entries.

## Specification

### Requirements

1. **Refactor `DeterministicLoadValue`**: Replace `stage_index::Integer` with `node_id::Integer` to reference graph node IDs directly. This allows load values to be mapped to specific nodes in any graph topology (linear, cyclic, branching).

2. **Update `DETERMINISTIC_LOAD_VALUE_SCHEMA`**: Change `FieldRule("stage_index", Integer; constraints = [positive()])` to `FieldRule("node_id", Integer; constraints = [positive()])`.

3. **Update `DeterministicLoad` lookup**: The `__get_load(bus_id, node_id, load)` function should look up load by `(bus_id, node_id)` instead of `(bus_id, stage_index)`.

4. **Update the `get_load` interface**: Change signature from `get_load(bus_id, stage_index, scenarios)` to `get_load(bus_id, node_id, scenarios)`.

5. **Refactor `__add_load_balance!`**: Remove the TODO comment and use `get_load(bus_ids[n], node, scenarios)` where `node` is already the graph node ID (which it currently is -- but the semantics are now correct).

6. **Add load-graph consistency validation**: During `ScenariosData` construction, validate that every `node_id` referenced in load values exists in the graph, and that every non-root graph node has load values for all buses.

7. **Update load CSV format**: Change the column name from `stage_index` to `node_id` in load CSV files.

8. **Update load JSONC inline format**: If load values are specified inline (not from CSV), the key name changes from `stage_index` to `node_id`.

9. **Update load validators**: The `__validate_sequential_deterministic_load_stage_indexes!` consistency check should be replaced with a graph-aware consistency check `__validate_deterministic_load_node_references!` that checks all `node_id` values exist in the graph.

### Inputs/Props

- `DeterministicLoadValue`: `bus_id::Integer`, `node_id::Integer`, `value::Real`
- Graph `nodes` vector (for cross-validation)

### Outputs/Behavior

- Load values are mapped to graph nodes, not stage indices
- The same load data can be used for linear, cyclic, or branching graphs
- Missing load values for a (bus, node) pair default to 0.0 (with a warning log)

### Error Handling

- Node ID in load data not found in graph: push `AssertionError("Load node_id (X) not found in graph")`
- Negative node_id: push `AssertionError("Load node_id (X) must be positive")`
- Missing load values for a bus at a graph node: emit `@warn` but do not error (default to 0.0)

## Acceptance Criteria

- [ ] Given a load CSV with `node_id` column, when `DeterministicLoad` is constructed, then load values are indexed by `(bus_id, node_id)`
- [ ] Given a call to `get_load(1, 2, scenarios)`, when node 2 has a load value of 100.0 for bus 1, then `100.0` is returned
- [ ] Given a call to `get_load(1, 99, scenarios)`, when node 99 has no load entry, then `0.0` is returned (with a warning)
- [ ] Given a load CSV that references `node_id: 99` and a graph without node 99, when `ScenariosData` is constructed, then validation fails with an appropriate error
- [ ] Given the 1dtoy example with updated load CSV (column renamed to `node_id`), when the full pipeline runs, then numerical results match the previous version
- [ ] Given a load CSV with the old `stage_index` column, when `DeterministicLoad` is constructed, then a clear error is raised about the missing `node_id` column
- [ ] Given the `__add_load_balance!` function in `build.jl`, when reviewed, then it no longer contains any TODO comments about load representation

## Implementation Guide

### Suggested Approach

1. **Start with the data type change**:
   - In `src/Scenarios/load.jl`, rename `stage_index` to `node_id` in `DeterministicLoadValue`
   - Update the `__get_load` function to use `node_id` instead of `stage_index`

2. **Update the schema** (if ticket-005 already defined `DETERMINISTIC_LOAD_VALUE_SCHEMA`):
   - Change `FieldRule("stage_index", ...)` to `FieldRule("node_id", ...)`

3. **Update validators** in `src/Scenarios/load-validators.jl`:
   - Update key names if any remaining manual validators reference `stage_index`
   - Replace `__validate_sequential_deterministic_load_stage_indexes!` with `__validate_deterministic_load_node_references!(d, graph, e)` that checks all node_ids exist in the graph

4. **Update `ScenariosData` construction** in `src/Scenarios/scenariosdata.jl` and `scenariosdata-validators.jl`:
   - Add a consistency validation step that cross-references load node_ids against graph node IDs
   - This requires passing the graph to the load consistency validator

5. **Update `__add_load_balance!`** in `src/Engines/sddp/build.jl`:
   - Remove the TODO comments
   - The function signature and logic remain essentially the same since `node` was already being passed as the graph node integer, but now the semantics are correct

6. **Update example data**:
   - Rename `stage_index` column to `node_id` in `example/1dtoy/data/load.csv`
   - Verify the values map correctly (in the 1dtoy case, `stage_index` values 1-4 correspond to `node_id` values 1-4 in the graph)

7. **Update tests**:
   - Update `LOAD_DICT` in `test/Scenarios/test-scenariosdata.jl` to use `node_id` instead of `stage_index`

### Key Files to Modify

- `src/Scenarios/load.jl` -- rename field, update lookup function
- `src/Scenarios/load-validators.jl` -- update schema, add graph-aware check
- `src/Scenarios/scenariosdata.jl` -- add cross-validation with graph
- `src/Scenarios/scenariosdata-validators.jl` -- update consistency validation
- `src/Engines/sddp/build.jl` -- remove TODO comments, clean up `__add_load_balance!`
- `example/1dtoy/data/load.csv` -- rename column
- `test/Scenarios/test-scenariosdata.jl` -- update test data

### Patterns to Follow

- Follow the schema validation pattern established in tickets 003-005
- Error messages should use `AssertionError` for content/consistency violations (matching existing codebase convention)
- The `__get_load` function should remain a dispatch on `LoadScenarios` subtypes

### Pitfalls to Avoid

- The 1dtoy example's load.csv uses sequential stage indices (1, 2, 3, 4) which happen to match node IDs -- but this is not guaranteed for other graph topologies. Make sure the lookup uses `node_id` not position.
- Do not change the abstract `LoadScenarios` type hierarchy -- `DeterministicLoad` remains a concrete subtype
- Do not remove the `get_load` function from the `Scenarios` module exports -- it is used by the engine's build pipeline
- The `__add_load_balance!` function receives `node::Integer` from the subproblem builder's closure -- this is already the graph node ID, so the function call semantics remain correct

## Testing Requirements

### Unit Tests

Update `test/Scenarios/test-scenariosdata.jl`:

- Valid ScenariosData with `node_id` in load data
- Invalid load with `node_id` referencing non-existent graph node
- Valid ScenariosData from file (load.csv with `node_id` column)

Add to load-specific tests (create `test/Scenarios/test-load.jl` if not existing):

- `DeterministicLoadValue` with valid `node_id`
- `DeterministicLoadValue` with negative `node_id`
- `DeterministicLoad` lookup by `(bus_id, node_id)` -- found
- `DeterministicLoad` lookup by `(bus_id, node_id)` -- not found (returns 0.0)

### Integration Tests

- Full pipeline test (`test/test-main.jl`) must pass with updated load format
- Study tests (`test/test-study.jl`) must pass

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-001 (merge), ticket-002 (graph validators -- needed for cross-validation), ticket-005 (schema migration -- load schema must exist), ticket-006 (cleanup -- clean codebase)
- **Blocks**: ticket-008 (example migration depends on new load format)

## Effort Estimate

**Points**: 4
**Confidence**: High
