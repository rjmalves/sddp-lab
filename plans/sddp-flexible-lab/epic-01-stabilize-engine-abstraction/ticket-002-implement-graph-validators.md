# ticket-002 Implement Graph Validators

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (pure Julia validation infrastructure, no SDDP domain knowledge needed)

## Context

### Background

The `abstract-engine` branch introduced a new `Graph` type in `src/Scenarios/graph.jl` that defines the scenario graph as an explicit set of `Node` and `Edge` objects parsed from a `graph.jsonc` file. However, the corresponding validators file (`src/Scenarios/graph-validators.jl`) is completely empty -- it contains only section comment headers with no actual validation functions. The `Graph` constructor in `graph.jl` also has several inline `# this ... should be moved to __validate` comments indicating that type conversions and validations were deferred.

### Relation to Epic

This is the second ticket in Epic 01. It fills a critical gap in the validation pipeline. Without graph validators, malformed graph configurations will cause cryptic runtime errors during model building instead of clear validation errors at parse time.

### Current State

**`src/Scenarios/graph-validators.jl`** (on abstract-engine):

```julia
# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

# CONTENT VALIDATORS -----------------------------------------------------------------------

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

# HELPERS -----------------------------------------------------------------------------------
```

**`src/Scenarios/graph.jl`** contains the `Graph(d::Dict, e::CompositeException)` constructor which directly calls `Int()`, `DateTime()`, `Real()` on dict values without validation, and `findfirst` on node arrays without checking for `nothing`.

**Node struct**:

```julia
struct Node
    id::Integer
    stage::Integer
    start_datetime::DateTime
    end_datetime::DateTime
end
```

**Edge struct**:

```julia
struct Edge
    source::Ref{Node}
    target::Ref{Node}
    probability::Real
    discount_rate::Real
end
```

## Specification

### Requirements

1. Implement validators for Node construction:
   - Keys validation: `id`, `stage`, `start_datetime`, `end_datetime` must all be present
   - Type validation: `id` and `stage` must be Integer, `start_datetime` and `end_datetime` must be String (convertible to DateTime)
   - Content validation: `id > 0`, `stage > 0`, `end_datetime > start_datetime`

2. Implement validators for Edge construction:
   - Keys validation: `source`, `target`, `probability`, `discount_rate` must all be present
   - Type validation: `source` and `target` must be Integer, `probability` and `discount_rate` must be Real
   - Content validation: `0 <= probability <= 1`, `discount_rate >= 0`, source and target node IDs must exist in the nodes list

3. Implement validators for Graph construction:
   - Keys validation: `nodes` and `edges` must be present
   - Type validation: `nodes` must be `Vector{Dict{String,Any}}`, `edges` must be `Vector{Dict{String,Any}}`
   - Content validation: at least 1 node, at least 0 edges (single-node graph is valid)
   - Consistency validation:
     - Exactly one root node (a node that is not a target of any edge)
     - All non-root nodes must be reachable from the root via edges
     - Outgoing edge probabilities from each node must sum to 1.0 (within tolerance 1e-6)
     - Node IDs must be unique
     - Stage numbers must be consistent with graph topology (source stage < target stage for acyclic, or source stage >= target stage only for explicit cycle-back edges)

4. Refactor `__build_node` and `__build_edge` in `graph.jl` to use the 4-step validation pattern (`build_internals -> validate_keys_types -> validate_content -> validate_consistency`)

### Inputs/Props

- `d::Dict{String,Any}` -- parsed JSONC dictionary for nodes, edges, and graph
- `e::CompositeException` -- error accumulator

### Outputs/Behavior

- Valid graph: returns `Graph(nodes, edges)` with properly typed fields
- Invalid graph: returns `nothing` and pushes descriptive error messages into `e`

### Error Handling

- Missing keys: push `ErrorException("Key 'X' not found in dictionary")`
- Invalid types: push `ErrorException("Key 'X' (value) can't be converted to Type")`
- Invalid content: push `AssertionError("Node id (X) must be positive")`
- Invalid consistency: push `AssertionError("Graph has N root nodes, expected exactly 1")`
- Edge references non-existent node: push `AssertionError("Edge source (X) references non-existent node")`
- Probabilities don't sum to 1: push `AssertionError("Outgoing probabilities from node X sum to Y, expected 1.0")`

## Acceptance Criteria

- [ ] Given a valid graph dict (like the 1dtoy example), when `Graph(d, e)` is called, then a `Graph` object is returned with `length(e) == 0`
- [ ] Given a graph dict missing the `nodes` key, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains an error about missing `nodes` key
- [ ] Given a graph with a node where `id` is negative, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains an error about invalid node id
- [ ] Given a graph with an edge referencing a non-existent node, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains an error about missing node reference
- [ ] Given a graph where outgoing probabilities from a node sum to 0.5, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains an error about probability sum
- [ ] Given a graph with two root nodes (two nodes not targeted by any edge), when `Graph(d, e)` is called, then `nothing` is returned and `e` contains an error about multiple roots
- [ ] Given a graph with duplicate node IDs, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains a duplicate ID error
- [ ] Given a graph where `end_datetime <= start_datetime` for a node, when `Graph(d, e)` is called, then `nothing` is returned and `e` contains a datetime validation error

## Implementation Guide

### Suggested Approach

1. **Start with Node validators** in `src/Scenarios/graph-validators.jl`:
   - `__validate_node_keys_types!(d, e)` -- check presence and types of `id`, `stage`, `start_datetime`, `end_datetime`
   - `__validate_node_content!(d, e)` -- check `id > 0`, `stage > 0`, parseable datetimes, `end > start`
   - `__validate_node_consistency!(d, e)` -- no cross-node checks needed at individual level
   - `__build_node_internals_from_dicts!(d, e)` -- convert strings to DateTime

2. **Refactor `__build_node`** in `graph.jl` to follow the 4-step pattern:

   ```julia
   function Node(d::Dict{String,Any}, e::CompositeException)
       valid_internals = __build_node_internals_from_dicts!(d, e)
       valid_keys_types = valid_internals && __validate_node_keys_types!(d, e)
       valid_content = valid_keys_types && __validate_node_content!(d, e)
       valid_consistency = valid_content && __validate_node_consistency!(d, e)
       return valid_consistency ? Node(d["id"], d["stage"], d["start_datetime"], d["end_datetime"]) : nothing
   end
   ```

3. **Edge validators**:
   - `__validate_edge_keys_types!(d, e)` -- check `source`, `target`, `probability`, `discount_rate`
   - `__validate_edge_content!(d, e)` -- check probability in [0,1], discount_rate >= 0
   - Add node existence check that takes the full nodes vector as context

4. **Graph-level validators**:
   - `__validate_graph_keys_types!(d, e)` -- check `nodes` and `edges` keys
   - `__validate_graph_content!(d, e)` -- at least 1 node
   - `__validate_graph_consistency!(d, e)` -- unique IDs, single root, probability sums, reachability

5. **Refactor `Graph(d, e)` constructor** to use validated node/edge construction with error accumulation.

### Key Files to Modify

- `src/Scenarios/graph-validators.jl` -- implement all validator functions (currently empty)
- `src/Scenarios/graph.jl` -- refactor constructors to use validation pipeline

### Patterns to Follow

Follow the exact same 4-step validation pattern used throughout the codebase. See `src/Engines/sddp/input.jl` for examples (e.g., `IterationLimit(d, e)`, `Convergence(d, e)`).

The pattern is:

1. `__build_X_internals_from_dicts!(d, e)` -- parse and convert internal objects
2. `__validate_X_keys_types!(d, e)` -- check key presence and types
3. `__validate_X_content!(d, e)` -- check value ranges and constraints
4. `__validate_X_consistency!(d, e)` -- check cross-field relationships

Error messages should follow existing conventions:

- Use `ErrorException` for missing keys and type mismatches
- Use `AssertionError` for content and consistency violations (note: the codebase uses `AssertionError` not `AssertionError` -- follow existing spelling)

### Pitfalls to Avoid

- Do not add `using Dates` to `graph-validators.jl` -- it is already available through the module chain (`Scenarios.jl` does not currently import Dates but `graph.jl` uses `DateTime`, so ensure `using Dates` is present in `Scenarios.jl`)
- The `findfirst` call in `__build_edge` returns `nothing` if the node is not found -- the validator must catch this before the constructor tries to index with `nothing`
- Probability sum tolerance should be `1e-6` not exact `1.0` to handle floating point accumulation
- Do not break the existing `Graph(filename::String, e)` constructor that reads from file -- it calls `Graph(d, e)` internally

## Testing Requirements

### Unit Tests

Add tests in `test/Scenarios/test-graph.jl`:

- Valid graph construction (existing test, verify it still works)
- Missing `nodes` key
- Missing `edges` key
- Node with negative `id`
- Node with `stage == 0`
- Node with `end_datetime <= start_datetime`
- Edge with `probability < 0`
- Edge with `probability > 1`
- Edge with negative `discount_rate`
- Edge referencing non-existent source node
- Edge referencing non-existent target node
- Graph with duplicate node IDs
- Graph with zero nodes
- Graph with multiple root nodes
- Graph with probabilities not summing to 1.0
- Graph from file (existing test via `Graph("graph.jsonc", e)`)

### Integration Tests

- The study read test (`test/test-study.jl` -> `study-sddp-read`) must still pass with the validated graph

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-001 (abstract-engine must be merged first)
- **Blocks**: ticket-003 (load refactor depends on validated graph)

## Effort Estimate

**Points**: 3
**Confidence**: High
