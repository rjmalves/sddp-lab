# ticket-048 Validate Same-Stage Node Datetimes in Graph Validators

## Context

### Background

The SDDP subproblem builder in `src/Engines/sddp/build.jl` constructs a `stage_datetimes` dict (lines 803-812) that maps each stage index to a `(start_datetime, end_datetime)` tuple. This dict is populated by iterating over all graph nodes, and the last node processed for a given stage overwrites any previous entry (line 808: `stage_datetimes[n.stage] = (n.start_datetime, n.end_datetime)`). If two nodes share the same stage but have different datetimes, the dict silently picks whichever node was last iterated -- producing incorrect `tau` values for some subproblems without any warning.

### Relation to Epic

This is an independent robustness improvement in Epic 12. It adds a validation check that prevents silent data corruption in the build pipeline. It is prerequisite for correctness of per-stage block architecture (Epic 11) where `tau` accuracy is critical for block duration validation.

### Current State

- `src/Scenarios/graph-validators.jl` contains the `__validate_graph_consistency!` function (lines 172-183) which calls four validators: unique IDs, single root, probability sums, and reachability
- There is NO validation that nodes at the same stage have the same datetimes
- `build.jl` lines 803-812 populate `stage_datetimes` with last-writer-wins semantics
- The `Node` struct (line 43-57 in `Scenarios.jl`) has fields: `id`, `stage`, `start_datetime`, `end_datetime`
- `test/Scenarios/test-graph.jl` tests graph construction and validation but has no same-stage datetime tests

## Specification

### Requirements

1. Add a new function `__validate_graph_stage_datetimes!(nodes::Vector{Node}, e::CompositeException)::Bool` to `src/Scenarios/graph-validators.jl`
2. For all nodes sharing the same `stage` value, verify they have identical `start_datetime` AND identical `end_datetime`
3. Accumulate errors into `CompositeException` following the existing pattern: one error per mismatch, with a message identifying the stage and the conflicting values
4. Wire the new validator into `__validate_graph_consistency!` as an additional check (after `__validate_graph_unique_node_ids!`)
5. The validator should check ALL stages, not short-circuit on the first mismatch

### Inputs/Props

- `nodes::Vector{Node}` from the parsed graph

### Outputs/Behavior

- Returns `true` if all nodes at each stage have matching datetimes
- Returns `false` and pushes errors to `CompositeException` if any mismatches are found

### Error Handling

- For each stage with mismatched datetimes, push an `AssertionError` with message: `"Graph - nodes at stage $stage have inconsistent datetimes: found $(start_dt_1) to $(end_dt_1) and $(start_dt_2) to $(end_dt_2)"`
- Multiple stages can have mismatches -- all are reported

## Acceptance Criteria

- [ ] Given a graph with nodes `{id=1, stage=1, 2024-01-01 to 2024-02-01}` and `{id=2, stage=1, 2024-01-01 to 2024-02-01}` (same stage, same datetimes), when `Graph(d, e)` is called, then construction succeeds and `length(e) == 0`
- [ ] Given a graph with nodes `{id=1, stage=1, 2024-01-01 to 2024-02-01}` and `{id=2, stage=1, 2024-03-01 to 2024-04-01}` (same stage, different datetimes), when `Graph(d, e)` is called, then construction fails (`graph === nothing`) and `e` contains an `AssertionError` with message matching `"stage 1"` and `"inconsistent datetimes"`
- [ ] Given a graph with two stages each having consistent datetimes, when `Graph(d, e)` is called, then construction succeeds
- [ ] Given a graph with two stages where only stage 2 has inconsistent datetimes, when `Graph(d, e)` is called, then construction fails and the error message references stage 2
- [ ] Given a graph with three stages where stages 1 and 3 have inconsistent datetimes, when `Graph(d, e)` is called, then `e` contains at least 2 errors (one per mismatched stage)

## Implementation Guide

### Suggested Approach

1. Add the validator function to `src/Scenarios/graph-validators.jl`:
   ```julia
   function __validate_graph_stage_datetimes!(
       nodes::Vector{Node}, e::CompositeException
   )::Bool
       stage_datetimes = Dict{Integer, Tuple{DateTime, DateTime}}()
       valid = true
       for node in nodes
           expected = get(stage_datetimes, node.stage, nothing)
           actual = (node.start_datetime, node.end_datetime)
           if expected === nothing
               stage_datetimes[node.stage] = actual
           elseif expected != actual
               push!(
                   e,
                   AssertionError(
                       "Graph - nodes at stage $(node.stage) have inconsistent datetimes: " *
                       "found $(expected[1]) to $(expected[2]) and $(actual[1]) to $(actual[2])"
                   ),
               )
               valid = false
           end
       end
       return valid
   end
   ```
2. Wire into `__validate_graph_consistency!` by adding a call after `__validate_graph_unique_node_ids!`:
   ```julia
   function __validate_graph_consistency!(
       nodes::Vector{Node}, edges::Vector{Edge}, e::CompositeException
   )::Bool
       valid_unique_ids = __validate_graph_unique_node_ids!(nodes, e)
       valid_stage_datetimes = __validate_graph_stage_datetimes!(nodes, e)  # NEW
       valid_single_root = __validate_graph_single_root!(nodes, edges, e)
       valid_probability_sums = __validate_graph_probability_sums!(nodes, edges, e)
       valid_reachability = __validate_graph_reachability!(nodes, edges, e)
       return valid_unique_ids &&
              valid_stage_datetimes &&
              valid_single_root &&
              valid_probability_sums &&
              valid_reachability
   end
   ```

### Key Files to Modify

- `src/Scenarios/graph-validators.jl` -- add `__validate_graph_stage_datetimes!` function, update `__validate_graph_consistency!` (line 172-183)
- `test/Scenarios/test-graph.jl` -- add test cases

### Patterns to Follow

- Follow the exact pattern of `__validate_graph_unique_node_ids!` (lines 90-95): iterate nodes, check condition, push `AssertionError`, return bool
- Follow the existing test pattern in `test/Scenarios/test-graph.jl`: create dict via `__make_valid_graph_dict()`, mutate it, construct `Graph(d, e)`, assert `graph === nothing` and error count

### Pitfalls to Avoid

- Do NOT use `@error` or `throw` -- always push to `CompositeException`
- Do NOT short-circuit after the first stage mismatch -- check all stages
- The validator takes only `nodes`, not `edges` -- it does not need edge information
- The function name must start with `__` (double underscore) to follow the module-internal naming convention

### Out of Scope

- Validating that stage indices are contiguous (1, 2, 3, ...) -- this is not currently validated and is a separate concern
- Validating that node datetimes form a chronological sequence across stages

## Testing Requirements

### Unit Tests

Add to `test/Scenarios/test-graph.jl`:

- `"same-stage-consistent-datetimes"` -- two nodes at stage 1 with identical datetimes, should succeed
- `"same-stage-inconsistent-start-datetime"` -- two nodes at stage 1 with different start datetimes, should fail
- `"same-stage-inconsistent-end-datetime"` -- two nodes at stage 1 with same start but different end, should fail
- `"multiple-stages-one-inconsistent"` -- stages 1 and 2 where stage 2 has mismatch, should fail with error referencing stage 2
- `"multiple-stages-both-inconsistent"` -- stages 1 and 2 both with mismatches, should fail with 2+ errors

### Integration Tests

- None required -- this is a pure validation function

### E2E Tests

- None required -- existing E2E tests already exercise the graph construction pipeline

## Dependencies

- **Blocked By**: None (independent)
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: High
