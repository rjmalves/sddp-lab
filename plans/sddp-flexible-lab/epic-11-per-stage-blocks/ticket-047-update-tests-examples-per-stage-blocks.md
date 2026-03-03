# ticket-047 Update Tests and Example Cases for Per-Stage Blocks

## Context

### Background

After tickets 044, 045, and 046 restructure `BlockConfig` to per-stage, update the subproblem builder, and reform the output format, the existing test suite and example cases must be updated to exercise the new per-stage block functionality and verify backward compatibility.

### Relation to Epic

This is the final ticket in Epic 11. It depends on all three preceding tickets and provides comprehensive test and example coverage for the per-stage block architecture.

### Current State

- `test/test-load-blocks.jl` (822 lines) tests the current global `BlockConfig`: parsing, default config, 2D variables, water balance modes, load balance, objective, and E2E with `1dtoy`
- The E2E tests at lines 640-821 construct `ScenariosData` with positional arguments, passing a single `BlockConfig` at position 7 (line 684, 761)
- `test/test-stage-duration.jl` tests tau computation and E2E with `1dtoy`
- Example cases in `examples/` use the current scenarios format

## Specification

### Requirements

1. Update `test/test-load-blocks.jl`:
   - Fix all positional `ScenariosData` constructor calls to pass `Dict{Int, BlockConfig}` instead of a single `BlockConfig`
   - Add tests for per-stage block configs with different K values per stage
   - Add tests for per-stage block configs with mixed parallel/chronological modes across stages
   - Add tests for the legacy `"blocks"` key deprecation warning
   - Add tests for the `"stage_blocks"` input format parsing
   - Update E2E tests to verify the new output format (block columns instead of name mangling)
2. Create a new test file `test/test-per-stage-blocks.jl` for per-stage-specific tests that would make `test-load-blocks.jl` too large
3. Add a new example case `examples/1dtoy_per_stage_blocks/` demonstrating per-stage blocks with stages of different durations
4. E2E test: build + train + simulate with per-stage blocks produces correct output format with `block_index` and `block_duration_hours` columns

### Inputs/Props

- Completed implementations from tickets 044, 045, 046

### Outputs/Behavior

- All existing tests pass (backward compatibility)
- New tests exercise per-stage block configs
- New example case runs successfully

### Error Handling

- Test both valid and invalid per-stage block configurations
- Test error accumulation when `"stage_blocks"` has invalid entries

## Acceptance Criteria

- [ ] Given `test/test-load-blocks.jl`, when `TEST_FILTER="test-load-blocks" julia --project -e 'using Pkg; Pkg.test()'` is run, then all tests pass including the updated E2E tests using `Dict{Int, BlockConfig}` positional arguments
- [ ] Given `test/test-per-stage-blocks.jl`, when `TEST_FILTER="test-per-stage" julia --project -e 'using Pkg; Pkg.test()'` is run, then all per-stage block tests pass
- [ ] Given the `examples/1dtoy_per_stage_blocks/` example with `"stage_blocks"` in `scenarios.jsonc`, when `SDDPlab.read_study` followed by `build`, `train`, and `simulate` are called, then the run completes without error
- [ ] Given the simulation output from the per-stage blocks example, when the output Parquet is read, then the DataFrame contains `block_index` and `block_duration_hours` columns with values matching the per-stage block definitions
- [ ] Given the existing `1dtoy` example (no blocks), when `TEST_FILTER="test-load-blocks" julia --project -e 'using Pkg; Pkg.test()'` is run, then the backward-compatible E2E test passes with `block_index = missing` in the output

## Implementation Guide

### Suggested Approach

1. **Update `test/test-load-blocks.jl`**:
   - At lines 684 and 761 (and similar), replace `block_config` positional arg with `Dict(1 => block_config, 2 => block_config, ...)` for all stages. The graph typically has stages 1-4 (from `1dtoy`), so create a dict covering all stages.
   - Verify that existing tests still pass with the dict format

2. **Create `test/test-per-stage-blocks.jl`**:
   - Test: construct `ScenariosData` with stage 1 having 2 parallel blocks and stage 2 having 3 chronological blocks. Build model, verify variable dimensions per stage.
   - Test: construct `ScenariosData` with `"stage_blocks"` JSON format, verify parsing
   - Test: construct `ScenariosData` with both `"blocks"` and `"stage_blocks"` keys, verify error
   - Test: build + train + simulate with per-stage blocks (3 iterations), verify completion
   - Test: save simulation results, read back, verify `block_index` and `block_duration_hours` columns

3. **Create `examples/1dtoy_per_stage_blocks/`**:
   - Copy `examples/1dtoy/` as a starting point
   - Modify `scenarios.jsonc` to use `"stage_blocks"` with different block definitions per stage
   - Ensure block durations sum to stage tau for each stage

4. **Update test output verification**:
   - Where tests check simulation output format, verify the new column schema

### Key Files to Modify

- `test/test-load-blocks.jl` -- positional constructor calls, E2E tests
- `test/test-per-stage-blocks.jl` -- new file
- `examples/1dtoy_per_stage_blocks/` -- new directory with scenarios.jsonc, graph.jsonc, etc.

### Patterns to Follow

- Follow the existing E2E test pattern in `test/test-load-blocks.jl` (lines 640-821): load study, modify scenarios, build engine, create study, suppress output, build/train/simulate
- Follow the existing example case structure in `examples/1dtoy/`

### Pitfalls to Avoid

- Do NOT run E2E tests with full iteration counts -- use 3 iterations max with `IterationLimit(3)` to keep test duration short
- Use `HiGHS.Optimizer` (not GLPK) for any threaded tests
- Create `test/test-per-stage-blocks.jl` as a separate file (not appending to `test-load-blocks.jl`) to avoid the SIGABRT issues documented in the test protocol
- The `runtests.jl` auto-discovers new test files via `__list_test_files`, so no manual registration needed

### Out of Scope

- Modifying the `BlockConfig` struct or parsing logic (ticket-044)
- Modifying the subproblem builder (ticket-045)
- Modifying the output format (ticket-046)

## Testing Requirements

### Unit Tests

- Per-stage block config construction and access tests
- Per-stage block validation error tests

### Integration Tests

- Full pipeline with per-stage blocks: build + train + simulate

### E2E Tests

- `1dtoy` backward compatibility with no blocks
- `1dtoy_per_stage_blocks` with per-stage blocks demonstrating different block counts per stage

## Dependencies

- **Blocked By**: ticket-044-restructure-blockconfig-per-stage.md, ticket-045-update-subproblem-builder-per-stage-blocks.md, ticket-046-reform-output-parquet-block-columns.md
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: High
