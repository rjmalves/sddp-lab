# ticket-008 Migrate Example Cases to New Input Format

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (data format migration, no algorithm expertise needed)

## Context

### Background

The `abstract-engine` branch updated the `1dtoy` example case to the new input format (introducing `graph.jsonc`, `scenarios.jsonc`, and restructured `main.jsonc` with the `engine` block). However, the other two example cases -- `1dsin` and `1dsin_ar` -- still use the old format with `algorithm.jsonc`, `stages.csv`, and `tasks.jsonc`. These must be migrated to the new format to ensure all examples work with the refactored codebase.

### Relation to Epic

This is the eighth ticket in Epic 01. It ensures all example cases are compatible with the new architecture. It depends on ticket-001 (merge), ticket-007 (load format uses `node_id`), and should be done after the load refactor to use the final format.

### Current State

**`example/1dtoy/`** (already migrated on abstract-engine):

- `main.jsonc` -- new format with `inputs` and `engine` blocks
- `data/graph.jsonc` -- explicit node/edge graph
- `data/scenarios.jsonc` -- references graph, inflow, load
- `data/load.csv` -- columns: `bus_id`, `node_id`, `value` (after ticket-007)

**`example/1dsin/`** (old format, on main):

- `main.jsonc` -- old format with `reading`, `algorithm`, `tasks` blocks
- `data/algorithm.jsonc` -- defines Regular/Cyclic scenario graph type, num_stages
- `data/stages.csv` -- defines stage durations
- `data/tasks.jsonc` -- defines policy and simulation tasks with convergence, risk, parallel settings
- `data/load.csv` -- old format with `stage_index`

**`example/1dsin_ar/`** (old format, on main):

- Same structure as `1dsin` but with AutoRegressive(1) inflow model
- `data/inflow_scenarios.jsonc` -- AR model with coefficients, copulas

## Specification

### Requirements

1. **Migrate `1dsin` example**:
   - Create `data/graph.jsonc` with 12 nodes (monthly stages for 1 year) and edges forming a linear chain
   - Create `data/scenarios.jsonc` with seed, initial_season, branchings, graph reference, inflow reference, load reference
   - Restructure `main.jsonc` to new format: `inputs` block (path + files) and `engine` block (SDDPEngine with policy/simulation config)
   - Update `data/load.csv` column from `stage_index` to `node_id`
   - Remove old files: `data/algorithm.jsonc`, `data/stages.csv`, `data/tasks.jsonc`

2. **Migrate `1dsin_ar` example**:
   - Same as above, but preserve the AutoRegressive stochastic process configuration
   - Ensure the AR parameters, copulas, and initial values are correctly mapped

3. **Verify numerical equivalence**: Run each migrated example through the full pipeline and verify that convergence bounds and simulation statistics are in the same ballpark (exact match is not required due to SDDP's stochastic nature, but the lower bound after the same number of iterations should match).

4. **Update test references**: If any tests reference the old example structure (e.g., reading `algorithm.jsonc`), update them.

### Inputs/Props

- Old format files from `example/1dsin/` and `example/1dsin_ar/`
- New format template from `example/1dtoy/` (after ticket-007)

### Outputs/Behavior

- All three example directories use the new format consistently
- Old-format files (`algorithm.jsonc`, `stages.csv`, `tasks.jsonc`) are removed
- Each example runs successfully through `read_study -> build -> train -> simulate -> save`

### Error Handling

- If an example fails to parse with the new format, check the graph node/edge definitions and the scenarios.jsonc reference structure

## Acceptance Criteria

- [ ] Given the `1dsin` example directory, when `read_study("example/1dsin")` is called, then a valid `Study` object is returned with no errors
- [ ] Given the migrated `1dsin` example, when the full pipeline (build -> train -> simulate -> save) is run, then no errors occur
- [ ] Given the `1dsin_ar` example directory, when `read_study("example/1dsin_ar")` is called, then a valid `Study` object is returned with no errors
- [ ] Given the migrated `1dsin_ar` example, when the full pipeline is run, then no errors occur and the AR stochastic process is correctly loaded
- [ ] Given any example directory, when `ls data/algorithm.jsonc` is checked, then the file does not exist (old format removed)
- [ ] Given any example directory, when `ls data/tasks.jsonc` is checked, then the file does not exist (old format removed)
- [ ] Given any example directory, when `data/graph.jsonc` is read, then it contains valid node/edge definitions

## Implementation Guide

### Suggested Approach

1. **Understand the 1dsin configuration** by reading the old-format files on `main`:
   - `example/1dsin/data/algorithm.jsonc` -- extract scenario graph type, number of stages, stage durations
   - `example/1dsin/data/tasks.jsonc` -- extract convergence settings, risk measure, parallel scheme
   - `example/1dsin/data/stages.csv` -- extract stage start/end dates
   - Map each old field to its new-format equivalent

2. **Create the new files** for 1dsin:
   - `graph.jsonc`: Create nodes 1-N (one per stage from stages.csv). Root node is node 0 or node 1. Edges connect sequential nodes with probability 1.0 and discount_rate 0.0. If the old format was "Cyclic", add a back-edge from the last node to an earlier node.
   - `scenarios.jsonc`: Copy seed, initial_season, branchings from old scenarios config. Reference `graph.jsonc`, inflow file, and load file.
   - `main.jsonc`: Use the template from 1dtoy. Set `inputs.path` to `"data"`, `inputs.files.scenarios` to `"scenarios.jsonc"`, `inputs.files.system` to `"system.jsonc"`. Copy policy/simulation config from old tasks.jsonc into the `engine.params` block.

3. **Update load.csv** column from `stage_index` to `node_id` and ensure values map to the correct graph node IDs.

4. **Repeat for 1dsin_ar**: Same process, but the inflow stochastic process is AutoRegressive instead of Naive.

5. **Delete old files** after migration is verified.

6. **Run tests** to ensure everything works.

### Key Files to Modify

- `example/1dsin/main.jsonc` -- restructure to new format
- `example/1dsin/data/graph.jsonc` -- create new
- `example/1dsin/data/scenarios.jsonc` -- create new
- `example/1dsin/data/load.csv` -- rename column
- `example/1dsin/data/algorithm.jsonc` -- delete
- `example/1dsin/data/stages.csv` -- delete
- `example/1dsin/data/tasks.jsonc` -- delete
- Same set of changes for `example/1dsin_ar/`

### Patterns to Follow

- Follow the exact format established by `example/1dtoy/` after the merge
- Use JSONC comments to document the purpose of each configuration block

### Pitfalls to Avoid

- The 1dsin example might use a Cyclic scenario graph (12 months repeating) -- check the old `algorithm.jsonc` for the graph type. If cyclic, the back-edge from the last month to the first month must have the appropriate probability and discount rate.
- The 1dsin_ar example uses AutoRegressive inflow with lag parameters and initial values. Ensure these are all preserved in the migration.
- Do not change the system data files (`system.jsonc`, `bus.csv`, `hydro.csv`, `thermal.csv`) -- only the algorithm/task/scenario configuration changes.

## Testing Requirements

### Unit Tests

- N/A (no new code is written, only config files)

### Integration Tests

- Add or update tests that read each example:
  - `read_study("example/1dsin")` succeeds
  - `read_study("example/1dsin_ar")` succeeds
  - Full pipeline for each example produces no errors

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-001 (merge), ticket-007 (load format finalized)
- **Blocks**: ticket-009 (comprehensive tests reference all examples)

## Effort Estimate

**Points**: 2
**Confidence**: High
