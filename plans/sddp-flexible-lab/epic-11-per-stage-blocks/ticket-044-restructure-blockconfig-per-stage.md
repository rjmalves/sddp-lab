# ticket-044 Restructure BlockConfig from Global to Per-Stage

## Context

### Background

The current `BlockConfig` is a single global property of `ScenariosData` (defined at line 134 of `src/Scenarios/Scenarios.jl`). Every stage in the SDDP model uses the same block mode and block definitions. This is limiting because real-world systems often have stages with different temporal resolutions -- for example, near-term stages might use hourly blocks while distant stages use weekly blocks, or stages with different calendar durations (e.g., January vs. February) naturally require different block definitions.

### Relation to Epic

This is the foundational ticket of Epic 11 (Per-Stage Block Architecture). It restructures the data model so that `BlockConfig` becomes per-stage. All subsequent tickets in this epic (045, 046, 047) depend on this change.

### Current State

- `ScenariosData` struct has a single field `block_config::BlockConfig` (line 134, `src/Scenarios/Scenarios.jl`)
- `get_block_config(scenarios)` returns this single config (line 185)
- The subproblem builder in `build.jl` reads this once at line 799: `block_config = get_block_config(scenarios)` and uses it identically for all nodes (lines 858-876)
- Parsing in `scenariosdata-validators.jl` function `__build_block_config!` (line 136) reads an optional `"blocks"` key from the scenarios dict and stores the result as `d["block_config"]`
- `BlockConfig` struct, `Block` struct, and all helpers are in `src/Scenarios/blocks.jl`

## Specification

### Requirements

1. Replace the single `block_config::BlockConfig` field in `ScenariosData` with `block_configs::Dict{Int, BlockConfig}` mapping stage index to block config
2. Add a new `get_block_config(scenarios, stage::Int)` method that returns the `BlockConfig` for a given stage, falling back to `default_block_config()` if the stage has no explicit config
3. Deprecate the single-argument `get_block_config(scenarios)` -- it should return the config for stage 1 with a deprecation warning (or error if configs differ across stages)
4. Update input parsing to support two formats:
   - **Legacy global format**: `"blocks": { "mode": "parallel", "definitions": [...] }` -- applies to ALL stages. Emit a `@warn` deprecation message.
   - **Per-stage format**: `"stage_blocks": { "1": { "mode": "parallel", "definitions": [...] }, "2": { "mode": "chronological", "definitions": [...] } }` -- each key is a stage index (as string, per JSON convention)
5. Validate: all nodes at the same stage MUST have the same `BlockConfig` (this is enforced by the stage-keyed dict design)
6. Validate: for each stage with explicit blocks, `abs(sum(block_durations) - stage_tau) > 1e-6` should produce a validation warning (not error, since tau is computed at build time from datetimes, and the block definitions are parsed before build)
7. If no blocks are specified for a stage, `default_block_config()` is used (single block = full stage duration)

### Inputs/Props

- `scenarios.jsonc` with optional `"blocks"` (legacy) or `"stage_blocks"` (new per-stage) key
- `ScenariosData` struct definition

### Outputs/Behavior

- `ScenariosData` exposes `block_configs::Dict{Int, BlockConfig}`
- `get_block_config(scenarios, stage)` returns the per-stage config
- Legacy input format continues to work with deprecation warning
- New per-stage format allows different block definitions per stage

### Error Handling

- If both `"blocks"` and `"stage_blocks"` are present, push an error to `CompositeException`: "Cannot specify both 'blocks' and 'stage_blocks' in scenarios config"
- If `"stage_blocks"` contains a non-integer key, push an error
- If `"stage_blocks"` contains a stage index that does not exist in the graph, push a warning (not error -- the builder will just ignore it)
- Individual `BlockConfig` parsing errors use the existing `BlockConfig(d, e)` constructor

## Acceptance Criteria

- [ ] Given a `scenarios.jsonc` with a legacy `"blocks"` key, when `ScenariosData` is parsed, then `block_configs` contains an entry for every stage in the graph with the same `BlockConfig`, and a `@warn` deprecation message is emitted
- [ ] Given a `scenarios.jsonc` with a `"stage_blocks"` key mapping stage 1 to parallel mode with 2 blocks and stage 2 to chronological mode with 3 blocks, when `ScenariosData` is parsed, then `get_block_config(scenarios, 1)` returns the parallel config and `get_block_config(scenarios, 2)` returns the chronological config
- [ ] Given a `scenarios.jsonc` with no `"blocks"` or `"stage_blocks"` key, when `ScenariosData` is parsed, then `get_block_config(scenarios, N)` returns `default_block_config()` for any stage N
- [ ] Given a `scenarios.jsonc` with both `"blocks"` and `"stage_blocks"` keys, when `ScenariosData` is parsed, then construction fails and `CompositeException` contains an error message mentioning both keys
- [ ] Given a `scenarios.jsonc` with `"stage_blocks"` containing a non-integer key like `"abc"`, when `ScenariosData` is parsed, then construction fails with an appropriate error in `CompositeException`

## Implementation Guide

### Suggested Approach

1. In `src/Scenarios/Scenarios.jl`, change the `ScenariosData` struct field from `block_config::BlockConfig` to `block_configs::Dict{Int, BlockConfig}`
2. Add method `get_block_config(scenarios::ScenariosData, stage::Int)::BlockConfig` that does `get(scenarios.block_configs, stage, default_block_config())`
3. Update the existing `get_block_config(scenarios::ScenariosData)::BlockConfig` to emit a deprecation warning and return the config for stage 1 (or the sole entry if all stages share one config)
4. In `src/Scenarios/scenariosdata-validators.jl`, update `__build_block_config!` to:
   - Check for mutual exclusion of `"blocks"` and `"stage_blocks"`
   - If `"blocks"` present: parse it, create a `Dict{Int, BlockConfig}` with the same config for all stages (stages are determined from the already-parsed graph at `d["graph"]`), emit `@warn`
   - If `"stage_blocks"` present: iterate its keys, parse each key as `Int`, parse each value as `BlockConfig(value_dict, e)`, build the dict
   - If neither present: store an empty `Dict{Int, BlockConfig}()` (the getter handles the fallback)
5. Update `ScenariosData(d, e)` constructor call to pass `d["block_config"]` as the `Dict{Int, BlockConfig}`
6. Update all callers of `get_block_config(scenarios)` in the codebase to use the two-argument form (the only caller is `build.jl` line 799 -- updated in ticket-045)
7. Update the export list in `Scenarios.jl` if needed

### Key Files to Modify

- `src/Scenarios/Scenarios.jl` -- `ScenariosData` struct definition (line 127-136), `get_block_config` function (line 185), exports (line 304-331)
- `src/Scenarios/scenariosdata-validators.jl` -- `__build_block_config!` (line 136-154), `UNCERTAINTIES_KEYS` (line 7-16), `UNCERTAINTIES_KEY_TYPES` (line 17-26)
- `src/Scenarios/scenariosdata.jl` -- `ScenariosData(d, e)` constructor (line 1-21)

### Patterns to Follow

- Follow the existing `__build_markov_chain!` pattern in `scenariosdata-validators.jl` (line 156-174) for optional config parsing with fallback
- Use `validate_schema!` from `src/Utils/schema.jl` for any new field validation
- Accumulate errors into `CompositeException` (never throw)

### Pitfalls to Avoid

- Do NOT change the `BlockConfig` struct itself or `blocks.jl` -- only the storage and access pattern changes
- Do NOT break the `DeterministicLoadValue.block_name` mechanism -- block-specific load values still reference block names
- Do NOT attempt to validate block duration sums at parse time (tau is not known until build time) -- only emit warnings
- The `test/test-load-blocks.jl` E2E tests construct `ScenariosData` directly with positional args (e.g., line 684) -- these must be updated to pass a `Dict{Int, BlockConfig}` instead of a single `BlockConfig`

### Out of Scope

- Modifying the subproblem builder to use per-stage configs (ticket-045)
- Changing the output format (ticket-046)
- Writing new E2E tests for per-stage blocks (ticket-047)

## Testing Requirements

### Unit Tests

- Test `__build_block_config!` with legacy `"blocks"` key: verify dict has entries for all graph stages
- Test `__build_block_config!` with `"stage_blocks"` key: verify per-stage parsing
- Test `__build_block_config!` with both keys: verify error
- Test `__build_block_config!` with neither key: verify empty dict
- Test `get_block_config(scenarios, stage)` returns correct config for specified stage
- Test `get_block_config(scenarios, stage)` returns default when stage has no explicit config
- Test `"stage_blocks"` with invalid key (non-integer string)

### Integration Tests

- Test full `ScenariosData` construction from dict with `"stage_blocks"`
- Test full `ScenariosData` construction from dict with legacy `"blocks"` (backward compat)

### E2E Tests

- Deferred to ticket-047

## Dependencies

- **Blocked By**: None (builds on completed epic-06)
- **Blocks**: ticket-045-update-subproblem-builder-per-stage-blocks.md, ticket-046-reform-output-parquet-block-columns.md, ticket-047-update-tests-examples-per-stage-blocks.md

## Effort Estimate

**Points**: 4
**Confidence**: High
