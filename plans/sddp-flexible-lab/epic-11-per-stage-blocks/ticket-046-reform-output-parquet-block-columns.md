# ticket-046 Reform Output Parquet Format with Block Columns

## Context

### Background

The current simulation output format in `src/Engines/sddp/save_simulation.jl` uses variable name mangling to represent block-indexed data. When a variable like `THERMAL_GENERATION` has multiple blocks, the `__increase_dataframe!` function (line 171-209) appends `_B{k}` to the variable name (line 189: `var_name = num_blk > 1 ? "$(name)_B$(k)" : name`). This produces column-unfriendly output where block membership is encoded in the variable name string rather than as a structured column.

### Relation to Epic

This ticket depends on ticket-045 (per-stage blocks in the builder) because the output must handle simulation results where different stages may have different numbers of blocks. It reforms the output layer to use explicit block columns.

### Current State

In `save_simulation.jl`:

- `__increase_dataframe!` (lines 171-209) iterates over entity indices `j` and block indices `k`, creating one row per `(entity, block)` combination
- Line 189: `var_name = num_blk > 1 ? "$(name)_B$(k)" : name` -- the mangling pattern
- Line 182: `num_blk = is_2d ? __get_num_blocks_from_sim(simulations, variable) : 1` -- detects block count from simulation data shape
- `__is_2d_variable` (lines 140-151) checks if the variable value is an `AbstractMatrix`
- `__get_num_blocks_from_sim` (lines 153-169) extracts block count from the matrix second dimension
- The final DataFrame has columns: `stage`, `variable_name`, `entity_id`, `scenario`, `value`
- Block identity is only recoverable by parsing the `_B{k}` suffix from `variable_name`

## Specification

### Requirements

1. Add two new columns to the simulation output DataFrame:
   - `block_index::Union{Int, Missing}` -- 1-based block index for block-indexed variables, `missing` for non-block-indexed variables (e.g., `STORED_VOLUME`, `INFLOW`, `STAGE_COST`)
   - `block_duration_hours::Float64` -- duration of the block in hours; for non-block-indexed variables, this equals the total stage duration `tau`
2. Remove the `_B{k}` name mangling from `variable_name` -- the variable name is always the clean name (e.g., `THERMAL_GENERATION`, not `THERMAL_GENERATION_B2`)
3. For non-block-indexed variables (1D), set `block_index = missing` and `block_duration_hours = tau` (total stage duration)
4. For block-indexed variables (2D), emit one row per `(entity, block)` with `block_index = k` and `block_duration_hours = tau_k[k]`
5. The `block_duration_hours` column requires access to per-stage block durations. This information must be passed through the simulation pipeline to the output writer.

### Inputs/Props

- `simulations::Vector{Vector{Dict{Symbol,Any}}}` -- raw SDDP simulation output
- `ScenariosData` with per-stage `block_configs` (from ticket-044)
- `SystemData` for entity mappings

### Outputs/Behavior

- Parquet files with columns: `stage`, `variable_name`, `entity_id`, `block_index`, `block_duration_hours`, `scenario`, `value`
- `block_index` is `Missing` for scalar/1D variables, `Int` for 2D block-indexed variables
- `variable_name` never contains `_B{k}` suffixes

### Error Handling

- If a stage has simulation data with a 2D variable but no `BlockConfig` is found for that stage, use `block_duration_hours = NaN` and emit `@warn`
- If `block_index` exceeds the number of blocks in the config, emit `@warn` (defensive, should not happen)

## Acceptance Criteria

- [ ] Given a simulation with 2 blocks at stage 1 and a `THERMAL_GENERATION` variable of size `(N, 2)`, when `Lab.save_simulation` is called, then the output DataFrame for `operation_thermals` contains rows where `variable_name == "THERMAL_GENERATION"` (no `_B` suffix), `block_index` is 1 or 2, and `block_duration_hours` matches the per-block durations from the `BlockConfig`
- [ ] Given a simulation with no blocks (K=1), when `Lab.save_simulation` is called, then `block_index` is `missing` for all block-eligible variables and `block_duration_hours` equals the stage tau
- [ ] Given a simulation with `STORED_VOLUME` (a state variable, not block-indexed), when `Lab.save_simulation` is called, then `block_index` is `missing` and `block_duration_hours` equals the stage tau
- [ ] Given the output DataFrame, when filtering by `variable_name == "THERMAL_GENERATION"` and `block_index == 2`, then exactly the data for block 2 is returned for all entities and scenarios
- [ ] Given the existing `1dtoy` example (no blocks), when running the full pipeline and saving, then the output has `block_index = missing` and `block_duration_hours` equal to the stage duration for all rows

## Implementation Guide

### Suggested Approach

1. Modify `Lab.save_simulation` to accept `ScenariosData` (or extract it from `files`) and pass it to `__write_simulation_results`
2. In `__write_simulation_results`, compute per-stage block durations:
   ```julia
   scenarios = get_scenarios(files)
   graph = get_graph(scenarios)
   stage_block_info = Dict{Int, Tuple{Vector{Float64}, Vector{String}}}()
   for node in graph.nodes
       stage = node.stage
       if !haskey(stage_block_info, stage)
           tau = Float64(Dates.value(node.end_datetime - node.start_datetime)) / 3_600_000.0
           bc = get_block_config(scenarios, stage)
           tau_k = get_block_durations(bc, tau)
           block_names = get_block_names(bc)
           stage_block_info[stage] = (tau_k, block_names)
       end
   end
   ```
3. Modify `__increase_dataframe!` signature to accept `stage_block_info` and add columns:
   - Replace line 189 (`var_name = ...`) with just `var_name = name` (always clean)
   - Add `block_index` column: `missing` when `num_blk == 1`, else `k`
   - Add `block_duration_hours` column: from `stage_block_info[stage][1][k]` (requires `stage` info per row)
4. Since `__increase_dataframe!` currently builds `internal_df` with a fixed `stage` column (`1:length(simulations[1])`), and each row already has a stage value, you can look up `stage_block_info[stage]` for each row's stage
5. Update the Parquet schema: ensure the `block_index` column is typed as `Union{Int, Missing}` in the DataFrame

### Key Files to Modify

- `src/Engines/sddp/save_simulation.jl` -- `Lab.save_simulation` (lines 1-18), `__write_simulation_results` (lines 211-319), `__increase_dataframe!` (lines 171-209)

### Patterns to Follow

- The existing `_unscale_simulations` pattern (lines 86-115) for iterating over simulation stages
- The existing `map_variable_output` dict (lines 222-242) for grouping variables into output files

### Pitfalls to Avoid

- Do NOT change the Parquet file names or the grouping of variables into files (e.g., `operation_thermals.parquet` stays)
- Do NOT remove the `STORED_VOLUME` `_IN`/`_OUT` direction suffix (line 281-293) -- this is separate from block mangling
- The `stage_objective`, `bellman_term`, `bellman_vertex_coverage_distance` renaming (lines 307-313) must be preserved
- The `sort!` at line 315 should include `block_index` in the sort columns
- `Missing` values in sort require `sort!(..., lt=isless)` or explicit handling

### Out of Scope

- Changing the input format (ticket-044)
- Backward-compatible reading of old Parquet files (document the format change)
- Changing the policy output format (`save_policy.jl`)

## Testing Requirements

### Unit Tests

- Test `__increase_dataframe!` with a 2D variable (2 blocks): verify `block_index` is 1 and 2, `variable_name` has no `_B` suffix
- Test `__increase_dataframe!` with a 1D variable: verify `block_index` is `missing`
- Test `__increase_dataframe!` with block duration info: verify `block_duration_hours` matches expected values

### Integration Tests

- Build and simulate a model with 2 blocks, save results, read back the Parquet: verify column schema and values
- Build and simulate a model with no blocks, save results, verify backward-compatible output schema

### E2E Tests

- Deferred to ticket-047

## Dependencies

- **Blocked By**: ticket-045-update-subproblem-builder-per-stage-blocks.md
- **Blocks**: ticket-047-update-tests-examples-per-stage-blocks.md

## Effort Estimate

**Points**: 3
**Confidence**: High
