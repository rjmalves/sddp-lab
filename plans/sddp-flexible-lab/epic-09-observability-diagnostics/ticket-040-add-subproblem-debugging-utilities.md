# ticket-040 Add Subproblem Debugging Utilities

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify JuMP model introspection and file I/O)

## Context

### Background

When SDDP training produces unexpected results (infeasible subproblems, poor bounds, numerical instability), users need to inspect individual subproblems to diagnose the cause. SDDP.jl provides two built-in debugging utilities:

1. `SDDP.write_subproblem_to_file(node, filename)` -- writes a single subproblem (LP/MPS) to disk for inspection
2. `SDDP.deterministic_equivalent(pg, optimizer)` -- constructs the extensive-form deterministic equivalent of the stochastic program (feasible only for small problems)

Currently, neither of these is exposed through SDDPlab's configuration or API. Users must drop into Julia REPL and manually call these functions with the internal `PolicyGraph` object.

This ticket adds a `DebugConfig` struct to the engine configuration that controls which debugging utilities to run, and a `debug` step in the pipeline that executes after training (or after build, for the deterministic equivalent). The debug output is written to a `debug/` subdirectory in the output path.

### Relation to Epic

This is the final ticket in Epic 09 (Observability and Diagnostics). It completes the observability suite by adding subproblem-level debugging tools. It does not depend on the convergence analysis from ticket-039 in a functional sense, but is ordered after it for epic coherence.

### Current State

- `SDDPModel` wraps `SDDP.PolicyGraph` with a `ScalingConfig` (in `src/Engines/Engines.jl`)
- The `PolicyGraph` nodes are accessed via `model.policy_graph.nodes` (a Dict mapping node IDs to `SDDP.Node` objects)
- `SDDPEngine` has 6 fields: `policy`, `simulation`, `diagnostics`, `solver`, `inflow_non_negativity`, `validation`
- The `diagnostics` field holds a `DiagnosticsConfig` with `run_numerical_report`, `warn_threshold`, `halt_threshold`
- The `study.jl` pipeline is: `read_study -> build -> diagnose -> train -> save_policy -> simulate -> save_simulation -> [validate -> save_validation]`
- There is no debug step in the pipeline
- `SDDP.write_subproblem_to_file(node::SDDP.Node, filename::String; throw_error=false)` writes a single node's subproblem
- `SDDP.deterministic_equivalent(pg::PolicyGraph, optimizer; time_limit=60.0)` returns a JuMP Model

## Specification

### Requirements

1. **New struct `DebugConfig`** with fields:
   - `write_subproblems::Bool` (default `false`) -- whether to write subproblem LP files
   - `subproblem_nodes::Vector{Any}` (default `[]` meaning all nodes) -- list of node identifiers to write; if empty, write all
   - `subproblem_format::String` (default `"mof"`) -- file format, one of `"mof"` (MathOptFormat JSON), `"lp"`, or `"mps"`
   - `deterministic_equivalent::Bool` (default `false`) -- whether to write the deterministic equivalent
   - `det_equiv_time_limit::Float64` (default `60.0`) -- time limit for deterministic equivalent construction

2. **New function `Lab.debug(model::SDDPModel, engine::SDDPEngine, path::String)`** that:
   - Creates a `debug/` subdirectory under `path`
   - If `write_subproblems` is true: iterates over the specified nodes (or all nodes) and calls `SDDP.write_subproblem_to_file(node, filepath)` for each
   - If `deterministic_equivalent` is true: calls `SDDP.deterministic_equivalent(model.policy_graph, optimizer)` and writes the result to a file

3. **Wire `DebugConfig`** into the engine:
   - Add as an optional `"debug"` key under the engine params (same level as `"diagnostics"`)
   - Default to all-false (no debugging) when the key is absent
   - Add `debug::DebugConfig` field to `SDDPEngine` (becomes 7 fields)

4. **Expose `debug` through `study.jl`**:
   - Add `debug(study::Study, model::Model, path::String)` function
   - This is called explicitly by the user, NOT automatically in the pipeline (debugging is opt-in and potentially slow)

5. **Programmatic API** (no automatic pipeline integration):
   - Users call `SDDPlab.debug(study, model, output_path)` after build/train
   - The Experiments runner does NOT call debug automatically

### Inputs/Props

JSONC configuration example:

```jsonc
{
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      "policy": { ... },
      "simulation": { ... },
      // NEW: optional debug config
      "debug": {
        "write_subproblems": true,
        "subproblem_nodes": [1, 2, 3],
        "subproblem_format": "lp",
        "deterministic_equivalent": true,
        "det_equiv_time_limit": 120.0
      }
    }
  }
}
```

When `subproblem_nodes` is empty or absent, all nodes are written.

### Outputs/Behavior

- `debug/` subdirectory created under the output path
- `debug/subproblem_<node_id>.<ext>` files for each requested node (e.g., `subproblem_1.lp`, `subproblem_2.lp`)
- `debug/deterministic_equivalent.<ext>` file if requested
- For Markov models, node IDs are tuples `(stage, state)` -- file names use `subproblem_<stage>_<state>.<ext>`
- A `debug/debug_summary.json` file listing what was written, elapsed time, and any errors

### Error Handling

- `SDDP.write_subproblem_to_file` may fail for infeasible nodes -- catch and log `@warn` per node, continue with remaining nodes
- `SDDP.deterministic_equivalent` may fail for large problems -- catch, `@warn`, and skip
- If the `debug/` directory cannot be created, `@warn` and return without error
- All errors are recorded in `debug_summary.json` rather than thrown
- If `DebugConfig` is absent (default), `debug()` is a no-op that returns immediately
- Invalid `subproblem_format` values are caught at configuration validation time

## Acceptance Criteria

- [ ] Given a JSONC config with no `debug` key, when `SDDPEngine` is constructed, then `debug` field has a `DebugConfig` with all defaults (both booleans false, empty nodes, format="mof", time_limit=60.0)
- [ ] Given a JSONC config with `write_subproblems: true` and `subproblem_nodes: [1, 2]`, when `debug(study, model, path)` is called after build, then `debug/subproblem_1.mof.json` and `debug/subproblem_2.mof.json` exist in the output directory
- [ ] Given `write_subproblems: true` with empty `subproblem_nodes`, when `debug` is called, then files for ALL graph nodes are written
- [ ] Given `deterministic_equivalent: true` with a small toy problem, when `debug` is called after build, then `debug/deterministic_equivalent.mof.json` exists
- [ ] Given `write_subproblems: true` with `subproblem_format: "lp"`, when `debug` is called, then files have `.lp` extension
- [ ] Given invalid `subproblem_format: "xyz"` in config, when `Study()` is constructed, then a validation error is accumulated
- [ ] Given default `DebugConfig` (all false), when `debug` is called, then no files are created and no errors occur
- [ ] Given a node that fails `write_subproblem_to_file`, when `debug` is called, then a `@warn` is logged and remaining nodes are still processed
- [ ] Given a successful debug run, when `debug_summary.json` is read, then it contains the list of written files, elapsed time, and any error messages

## Implementation Guide

### Suggested Approach

1. **Define `DebugConfig` struct** in `src/Engines/Engines.jl`:

   ```julia
   struct DebugConfig
       write_subproblems::Bool
       subproblem_nodes::Vector{Any}
       subproblem_format::String
       deterministic_equivalent::Bool
       det_equiv_time_limit::Float64
   end
   ```

   Add as 7th field to `SDDPEngine`.

2. **Add constructor and validator** following the established pattern:
   - `DebugConfig(d::Dict{String,Any}, e::CompositeException)` in `src/Engines/sddp/input.jl`
   - `DEBUG_CONFIG_SCHEMA` in `src/Engines/sddp/input-validators.jl` with constraints (format must be one of "mof", "lp", "mps"; time_limit must be positive)
   - `__build_debug!` builder with defaults when key is absent
   - Add to `__build_sddp_engine_internals_from_dicts!` and `__validate_sddp_engine_keys_types!`

3. **Create `src/Engines/sddp/debug.jl`** with the debug implementation:

   ```julia
   function Lab.debug(model::SDDPModel, engine::SDDPEngine, path::String)
       config = engine.debug
       if !config.write_subproblems && !config.deterministic_equivalent
           return nothing
       end
       # ... create debug/ dir, iterate nodes, write files
   end
   ```

4. **Subproblem writing logic**:
   - Get the file extension from format: `"mof" -> ".mof.json"`, `"lp" -> ".lp"`, `"mps" -> ".mps"`
   - Get nodes from `model.policy_graph.nodes` (a Dict)
   - Filter to requested nodes if `subproblem_nodes` is non-empty
   - For each node, call `SDDP.write_subproblem_to_file(node_obj, filepath; throw_error=false)`
   - Handle integer vs tuple node IDs for file naming

5. **Deterministic equivalent logic**:
   - Create optimizer via `create_optimizer(engine.solver)`
   - Call `SDDP.deterministic_equivalent(model.policy_graph, optimizer; time_limit=config.det_equiv_time_limit)`
   - Write the result using `JuMP.write_to_file(det_model, filepath)`

6. **Write debug summary**:
   - Collect metadata: files written, errors encountered, elapsed time
   - Write to `debug/debug_summary.json`

7. **Include and wire**:
   - Add `include("sddp/debug.jl")` in `src/Engines/sddp.jl`
   - Add `debug(study::Study, model::Model, path::String)` in `src/study.jl`
   - Export `debug` from `src/SDDPlab.jl`

### Key Files to Modify

- `src/Engines/Engines.jl` -- add `DebugConfig` struct, add field to `SDDPEngine`, update exports
- `src/Engines/sddp/input.jl` -- add `DebugConfig` constructor, `__build_debug!`
- `src/Engines/sddp/input-validators.jl` -- add `DEBUG_CONFIG_SCHEMA`, update engine validators
- `src/Engines/sddp/debug.jl` -- NEW file with debug logic
- `src/Engines/sddp.jl` -- add include for `debug.jl`
- `src/study.jl` -- add `debug` function
- `src/SDDPlab.jl` -- add `debug` to exports

### Patterns to Follow

- Follow `__build_diagnostics!` pattern for optional config with defaults (in `src/Engines/sddp/input.jl`)
- Follow `__build_validation!` pattern for Union-type optional field processing
- Follow `Lab.save_policy` pattern for directory management (`pwd()` save/restore)
- Follow `__write_validation_statistics` pattern for JSON output writing
- Follow the `try-catch` with `@warn` pattern used in `validate.jl` for SDDP.jl calls that may fail

### Pitfalls to Avoid

- `model.policy_graph.nodes` is a `Dict`, not an `Array`. For integer node graphs, keys are `Int`; for Markov graphs, keys are `Tuple{Int,Int}`. Handle both.
- `SDDP.write_subproblem_to_file` takes a `SDDP.Node` object, NOT a node ID. You must look up the node: `node_obj = model.policy_graph[node_id]` or `model.policy_graph.nodes[node_id]`
- The `subproblem_nodes` config field contains `Any` because nodes can be integers or tuples. Validate that each element matches the graph's node type.
- `SDDP.deterministic_equivalent` may return a very large model for problems with many stages/scenarios. The `time_limit` kwarg prevents infinite computation, but file size can still be huge. Document this.
- Do NOT add the `debug` call to the automatic pipeline in `src/Experiments/runner.jl` -- it should be opt-in only.
- When adding `debug` to `SDDPEngine` (7th field), update ALL places where `SDDPEngine(...)` is constructed (the constructor in `input.jl` and the `__build_sddp_engine_internals_from_dicts!` validator).
- The `Lab.debug` function must be defined with the correct method signature to work with the abstract `Model` and `Engine` types in study.jl.
- `JuMP.write_to_file` needs the full path including extension. For MathOptFormat, use `.mof.json`.

## Testing Requirements

### Unit Tests

Create `test/test-debug.jl`:

- Test `DebugConfig` default constructor (no dict keys)
- Test `DebugConfig` with all fields specified
- Test `DebugConfig` with invalid `subproblem_format` (not in allowed list)
- Test `DebugConfig` with negative `det_equiv_time_limit`
- Test `SDDPEngine` construction with and without `debug` key
- Test that debug field has correct defaults when absent

### Integration Tests

In the same file, using `example/1dtoy` with `max_iterations: 3`:

- Build a model, then call `debug` with `write_subproblems: true`:
  - Verify subproblem files are created in `debug/` subdirectory
  - Verify file count matches number of graph nodes (or filtered subset)
  - Verify files are non-empty and valid (can be parsed)
- Build a model, then call `debug` with `deterministic_equivalent: true`:
  - Verify `deterministic_equivalent.mof.json` (or `.lp`) is created
  - Verify file is non-empty
- Call `debug` with default config (all false):
  - Verify no `debug/` directory is created
- Verify `debug_summary.json` content after a debug run

Use `mktempdir() do tmpdir ... end` for output tests.
Use `TEST_FILTER="test-debug"` with 180000ms timeout.

### E2E Tests

Not required for this ticket.

## Dependencies

- **Blocked By**: ticket-039
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: High
