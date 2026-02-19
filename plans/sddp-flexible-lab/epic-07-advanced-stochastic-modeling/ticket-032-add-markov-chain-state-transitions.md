# ticket-032 Add Markov Chain State Transitions

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify MarkovianGraph integration with existing graph validators)

## Context

### Background

SDDPlab currently uses `SDDP.LinearPolicyGraph` (via `SDDP.PolicyGraph` with an integer-node `SDDP.Graph`) where each node represents a single stage and the stochastic process within each stage is stagewise-independent (SAA samples drawn from the same distribution). This limits the system to a single hydrological regime per stage.

Real hydro systems exhibit regime-switching behavior: dry/normal/wet periods have distinct statistical parameters. SDDP.jl natively supports this via `SDDP.MarkovianGraph` where each node is identified by a `(stage, markov_state)` tuple and transition probabilities define how the system moves between states across stages. The subproblem builder receives the tuple and can condition parameters on the Markov state.

This ticket adds Markov chain support by: (a) extending the scenarios JSONC to specify transition matrices, (b) building a `SDDP.MarkovianGraph` instead of a `SDDP.Graph` when Markov states are configured, and (c) conditioning the stochastic process parameters on the Markov state within each subproblem.

### Relation to Epic

This is the second ticket in Epic 07. It builds on ticket-031 (which adds `VectorAutoRegressive`) by enabling regime-dependent stochastic process parameters. The out-of-sample validation in ticket-033 will test policies trained with Markov chain graphs.

### Current State

- `src/Scenarios/Scenarios.jl`: `ScenariosData` has 7 fields including `graph::Graph` and `inflow::InflowScenarios`. The `Graph` struct holds `Vector{Node}` and `Vector{Edge}` where `Node` has integer `id` and `stage` fields.
- `src/Engines/sddp/build.jl`: `__build_graph(files)` creates a `SDDP.Graph` with integer nodes. The `fun_sp_build(m, node::Integer)` closure receives an integer node ID. `add_uncertainties!(m, scenarios, node, method)` converts node to season via `__node2season`.
- `src/Scenarios/graph.jl`: `Graph(d, e)` constructs from JSONC dict with `nodes` and `edges`.
- `src/Scenarios/graph-validators.jl`: Validates node IDs, edge probabilities summing to 1.0, reachability, single root.
- `SDDP.jl` API: `SDDP.MarkovianGraph(transition_matrices::Vector{Matrix{Float64}})` creates a graph with `(stage, markov_state)` tuple nodes. `SDDP.PolicyGraph(builder, graph; ...)` works with any graph type -- the builder receives the node type matching the graph.

## Specification

### Requirements

1. **New `MarkovChainConfig` type**: Holds transition matrices and metadata. Parsed from an optional `"markov_chain"` key in the scenarios JSONC.
2. **Conditional graph construction**: When `markov_chain` is absent, use the existing `__build_graph` with integer nodes (no regression). When present, use `SDDP.MarkovianGraph(transition_matrices)` to build a graph with `(stage, markov_state)` tuple nodes.
3. **Subproblem builder adaptation**: The `fun_sp_build` closure must handle both `node::Integer` (legacy) and `node::Tuple{Int,Int}` (Markov). When Markov, extract `(stage, markov_state)` and use `markov_state` to select regime-specific stochastic process parameters.
4. **Regime-dependent stochastic process**: The stochastic process (any type: `Naive`, `AutoRegressive`, `VectorAutoRegressive`) should support multiple parameter sets indexed by Markov state. This is achieved by having `InflowScenarios` hold a `Dict{Int, AbstractStochasticProcess}` (one process per Markov state) instead of a single process. When no Markov chain is configured, the dict has a single entry at key `1`.
5. **SAA per Markov state**: SAA generation must produce separate noise scenarios per Markov state. The `SDDP.parameterize` call selects the appropriate SAA based on the current node's Markov state.
6. **Backward compatibility**: All existing JSONC configurations (no `markov_chain` key) must continue to work unchanged.

### Inputs/Props

JSONC scenarios configuration with Markov chain:

```jsonc
{
  "seed": 12345,
  "initial_season": 1,
  "branchings": 50,
  "graph": {
    "kind": "Graph",
    "params": {
      // ... existing graph nodes/edges (used for stage structure)
    },
  },
  "markov_chain": {
    "transition_matrices": [
      [[0.5, 0.5]], // Stage 1: root -> 2 states (1x2 matrix)
      [
        [0.8, 0.2],
        [0.3, 0.7],
      ], // Stage 2+: 2x2 transition
    ],
  },
  "inflow": {
    "stochastic_process": {
      "1": {
        "kind": "AutoRegressive",
        "params": {
          /* dry regime params */
        },
      },
      "2": {
        "kind": "AutoRegressive",
        "params": {
          /* wet regime params */
        },
      },
    },
  },
  "load": {
    /* ... */
  },
}
```

When `markov_chain` is absent, `inflow.stochastic_process` is a single `{"kind": ..., "params": ...}` dict (existing format). When present, it is a dict of `{"1": {...}, "2": {...}}` keyed by Markov state index (string keys because JSON keys are strings).

### Outputs/Behavior

- When `markov_chain` is present: `SDDP.PolicyGraph` is created with a `SDDP.MarkovianGraph`, node indices are `(stage, markov_state)` tuples, and each subproblem uses regime-specific stochastic process parameters.
- When `markov_chain` is absent: behavior is identical to the current system (integer node IDs, single stochastic process).
- SAA is generated per Markov state with independent seeds (base seed + state offset).
- The simulation output format does not change -- SDDP.jl handles the tuple node internally.

### Error Handling

- Invalid transition matrix dimensions (not matching stage count or state count): accumulate `AssertionError`
- Transition matrix rows not summing to 1.0 (within tolerance): accumulate `AssertionError`
- First transition matrix not having 1 row: accumulate `AssertionError`
- Mismatch between number of Markov states in transition matrices and number of stochastic process entries in `inflow`: accumulate `AssertionError`
- Follow the backward-compat pattern: `haskey(d, "markov_chain")` to detect presence

## Acceptance Criteria

- [ ] Given a scenarios JSONC without `"markov_chain"` key, when the model is built, then the graph uses integer node IDs and the system behaves identically to pre-ticket behavior.
- [ ] Given a scenarios JSONC with `"markov_chain"` containing 2 states and 3 stages, when the model is built, then the `SDDP.PolicyGraph` has `(stage, markov_state)` tuple nodes and the correct number of nodes (1 root + states per stage).
- [ ] Given a Markov chain config with 2 states and per-state `AutoRegressive` processes, when the subproblem builder runs for node `(2, 1)`, then it uses the dry-regime AR parameters; for node `(2, 2)`, it uses the wet-regime parameters.
- [ ] Given a Markov chain config, when SAA is generated, then each Markov state gets independent noise scenarios and the `SDDP.parameterize` call uses the correct SAA for the node's state.
- [ ] Given invalid transition matrices (wrong dimensions, rows not summing to 1.0), when parsed, then construction returns `nothing` with descriptive errors in `CompositeException`.
- [ ] Given a Markov chain with 2 states but only 1 stochastic process definition in `inflow`, then construction returns `nothing` with a mismatch error.
- [ ] Given a Markov chain config with `VectorAutoRegressive` processes, when the model is built, then VAR constraints use regime-specific coefficient matrices.

## Implementation Guide

### Suggested Approach

1. **Create `src/Scenarios/markov-validators.jl`**: Validate the `markov_chain` dict:
   - `transition_matrices` key must be a `Vector{Vector{Vector{Float64}}}` (JSON arrays of arrays)
   - Convert to `Vector{Matrix{Float64}}` during parsing
   - First matrix must have 1 row
   - Each subsequent matrix must have rows equal to columns of the previous matrix
   - All rows must sum to 1.0 (within 1e-6 tolerance)
   - At least 1 transition matrix

2. **Create `src/Scenarios/markov.jl`**: Define `MarkovChainConfig` struct:

   ```julia
   struct MarkovChainConfig
       transition_matrices::Vector{Matrix{Float64}}
       num_states::Int  # columns of first matrix = number of Markov states
   end
   ```

   Constructor from dict with validation.

3. **Extend `ScenariosData`**: Add an optional `markov_chain` field. Per the established pattern (epic-06 learnings), fields are always required with a default value:
   - Add `markov_chain::Union{MarkovChainConfig,Nothing}` -- BUT per learnings, this is normally avoided. Instead: define a `NoMarkovChain` sentinel type and `AbstractMarkovChain` hierarchy:
     ```julia
     abstract type AbstractMarkovChain end
     struct NoMarkovChain <: AbstractMarkovChain end
     struct MarkovChainConfig <: AbstractMarkovChain ... end
     ```
   - `ScenariosData` gets field `markov_chain::AbstractMarkovChain`
   - Default: `NoMarkovChain()` when key is absent (backward compat via `haskey`)
   - `has_markov_chain(mc::NoMarkovChain) = false`; `has_markov_chain(mc::MarkovChainConfig) = true`

4. **Extend `InflowScenarios`**: Change from `stochastic_process::AbstractStochasticProcess` to `stochastic_processes::Dict{Int,AbstractStochasticProcess}`. When no Markov chain, the dict has key `1` mapping to the single process. Add accessor: `get_stochastic_process(inflow, markov_state::Int)`.

5. **Modify `src/Scenarios/inflow.jl`**: Update `InflowScenarios` constructor to detect whether `stochastic_process` is a single dict (legacy) or a dict-of-dicts (Markov). For legacy: build single process, store in `Dict(1 => process)`. For Markov: iterate keys, build each process, store in dict.

6. **Modify `src/Engines/sddp/build.jl`**:
   - `__build_graph(files)`: Check `has_markov_chain(scenarios.markov_chain)`. If true, use `SDDP.MarkovianGraph(mc.transition_matrices)`. If false, use existing integer graph.
   - `__generate_subproblem_builder`: Make generic over node type. When Markov, `node` is a tuple `(stage, markov_state)`. Extract `stage` for datetime lookup, `markov_state` for process selection.
   - SAA generation: generate per Markov state. Store as `Dict{Int, Vector{Vector{Vector{Float64}}}}`.
   - `SDDP.parameterize`: select `SAA[markov_state][stage_index]`.
   - `add_uncertainties!`: pass the correct stochastic process for the current Markov state.

7. **Update `src/Scenarios/Scenarios.jl`**: Add includes for markov files, update `ScenariosData` struct, add exports.

8. **Update `src/Scenarios/scenariosdata.jl`**: Add Markov chain building in `__build_scenarios_internals_from_dicts!`.

9. **Update `src/Scenarios/scenariosdata-validators.jl`**: Add `markov_chain` to UNCERTAINTIES_KEYS with type `T where {T<:AbstractMarkovChain}`.

### Key Files to Modify

- **New**: `src/Scenarios/markov-validators.jl`
- **New**: `src/Scenarios/markov.jl`
- **Modify**: `src/Scenarios/Scenarios.jl` (add includes, update `ScenariosData` struct, exports)
- **Modify**: `src/Scenarios/scenariosdata.jl` (Markov chain building in internals)
- **Modify**: `src/Scenarios/scenariosdata-validators.jl` (add markov_chain to schema)
- **Modify**: `src/Scenarios/inflow.jl` (multi-process InflowScenarios)
- **Modify**: `src/Scenarios/inflow-validators.jl` (detect single vs multi-process format)
- **Modify**: `src/Engines/sddp/build.jl` (`__build_graph`, `__generate_subproblem_builder`, SAA generation, `add_uncertainties!`)
- **New**: `test/Scenarios/test-markov.jl`

### Patterns to Follow

- Backward-compat via `haskey(d, "markov_chain")` guard in internals builder (same as `"modeling"` key pattern from epic-06)
- Abstract type hierarchy for optional components (`NoMarkovChain` / `MarkovChainConfig` like `InflowNone` / `InflowPenalty`)
- `CompositeException` accumulation for validation errors
- Graph validator pattern from `src/Scenarios/graph-validators.jl` for transition matrix validation
- Node datetime lookup pattern: the existing code uses `node_datetimes[node]` -- for Markov, index by stage: `node_datetimes[node[1]]` or build a separate stage-to-datetime map

### Pitfalls to Avoid

- **Node type change**: `SDDP.MarkovianGraph` produces `(stage, markov_state)` tuple nodes. The subproblem builder signature `fun_sp_build(m, node)` must handle both `Integer` and `Tuple{Int,Int}`. Use dispatch or runtime check.
- **Node datetimes**: The current `node_datetimes` dict maps `node_id::Int => (start_dt, end_dt)`. With Markov, multiple nodes per stage share the same datetimes. Build a `stage_datetimes` map instead and extract stage from the node (either `node` for Int or `node[1]` for tuple).
- **SAA indexing**: Currently `SAA[node]` is indexed by the stage-order integer. With Markov, index by `(markov_state, stage_index)`. The stage index within the Markov graph may not match the node tuple directly -- compute it from `node[1]`.
- **Root node**: `SDDP.MarkovianGraph` uses `(0, 1)` as root. The existing code uses `get_root_node_id(g)` which returns an integer. The Markov path bypasses the existing graph entirely and constructs the SDDP graph directly from transition matrices.
- **Simulation output**: SDDP.jl handles tuple nodes internally during simulation. The simulation output format (stage-indexed dicts) should still work because `simulations[i]` is still a vector of stage dicts. Verify this does not break `save_simulation`.
- **Test isolation**: Use `TEST_FILTER="test-markov"` with 120000ms timeout for unit tests.

## Testing Requirements

### Unit Tests

Create `test/Scenarios/test-markov.jl`:

1. **MarkovChainConfig constructor**: Valid 2-state config constructs; invalid dimensions fail; rows not summing to 1.0 fail; first matrix not 1-row fails
2. **ScenariosData with Markov**: Full ScenariosData construction with markov_chain key; backward compat without key
3. **InflowScenarios multi-process**: Dict-of-dicts inflow parsing; single-dict legacy parsing
4. **Graph building**: `__build_graph` produces `SDDP.MarkovianGraph` when Markov is configured; integer graph when not
5. **Subproblem builder**: Using `SDDP.PolicyGraph` with `SDDP.MarkovianGraph`, verify that different Markov states produce different AR constraints (different coefficient values in the constraint matrix)

### Integration Tests

- Build an SDDP model with 2 Markov states and `AutoRegressive` processes. Verify model construction completes and has the expected number of nodes.
- Verify simulation runs and produces output without errors.

### E2E Tests (if applicable)

Not required. Full policy quality testing deferred to ticket-033.

## Dependencies

- **Blocked By**: ticket-031 (VectorAutoRegressive must exist for VAR + Markov combination testing, and InflowScenarios refactoring in this ticket must account for all process types)
- **Blocks**: ticket-033 (out-of-sample validation needs Markov support for regime-dependent testing)

## Effort Estimate

**Points**: 5
**Confidence**: Medium (the SDDP.jl MarkovianGraph API is well-documented and this follows established patterns, but the changes touch many files across Scenarios and Engines)
