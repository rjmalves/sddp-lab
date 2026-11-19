# ticket-051 Add PrecompileTools Dependency and compile_workload Scaffold

## Context

### Background

SDDPlab depends on JuMP.jl, SDDP.jl, and HiGHS.jl -- packages with heavy type-specialized codegen. The first execution in a fresh Julia session pays a steep TTFX (Time To First Execution) compilation tax. PrecompileTools.jl allows defining representative workloads that run during precompilation, caching native code to disk via Julia's pkgimage system (Julia >= 1.9). This ticket adds the PrecompileTools dependency and creates the structural scaffold (`@compile_workload` block in `SDDPlab.jl`) that the next ticket will populate with the actual SDDP training workload.

### Relation to Epic

This is the first ticket in Epic 13 (Precompilation & Logging Control). It establishes the infrastructure that ticket-052 (smart workload) and ticket-053 (output suppression) build upon.

### Current State

- `SDDPlab.jl` at `/home/rogerio/git/sddp-lab/src/SDDPlab.jl` has no PrecompileTools dependency
- `Project.toml` at `/home/rogerio/git/sddp-lab/Project.toml` does not list PrecompileTools
- The module defines `SDDPlab` (lowercase 'l') and exports `read_study`, `build`, `train`, `simulate`, `save_policy`, `save_simulation`
- HiGHS is currently a test-only dependency (in `[extras]`), but the precompile workload needs it at precompile time

## Specification

### Requirements

1. Add `PrecompileTools` to `[deps]` in `Project.toml` with a compat entry for the latest stable version (>= 1.2)
2. Move `HiGHS` from `[extras]` to `[deps]` in `Project.toml` so it is available during precompilation. Keep it also in `[extras]`/`[targets]` for tests. Add a compat entry.
3. Add `using PrecompileTools` in `src/SDDPlab.jl`
4. Add a `@compile_workload begin ... end` block at the end of `src/SDDPlab.jl` (after all includes and exports) that contains a placeholder comment `# Workload implemented in ticket-052`
5. Create a new file `src/precompile_workload.jl` that will be `include`d inside the `@compile_workload` block. Initially this file should contain only a comment explaining its purpose

### Inputs/Props

- `Project.toml`: current dependency list
- `src/SDDPlab.jl`: main module file

### Outputs/Behavior

- After this ticket, `using SDDPlab` should succeed without errors
- PrecompileTools should be importable within the module
- The `@compile_workload` block should execute (even if it does nothing yet)
- All existing tests must continue to pass

### Error Handling

- If PrecompileTools fails to load, the module should still define all types and functions (PrecompileTools is compile-time only and does not affect runtime behavior)

## Acceptance Criteria

- [ ] Given a fresh Julia session, when `using Pkg; Pkg.instantiate()` is run in the project, then PrecompileTools and HiGHS are installed as direct dependencies
- [ ] Given `Project.toml`, when inspected, then `PrecompileTools` appears in `[deps]` with a `[compat]` entry of `">= 1.2"`
- [ ] Given `Project.toml`, when inspected, then `HiGHS` appears in `[deps]` with a `[compat]` entry, AND remains in `[extras]` and `[targets].test`
- [ ] Given `src/SDDPlab.jl`, when inspected, then `using PrecompileTools` appears before the `@compile_workload` block
- [ ] Given `src/SDDPlab.jl`, when inspected, then a `@compile_workload begin ... end` block exists after all `export` statements and includes `src/precompile_workload.jl`

## Implementation Guide

### Suggested Approach

1. Edit `/home/rogerio/git/sddp-lab/Project.toml`:
   - Add `PrecompileTools = "aea7be01-6a6a-4083-8856-8a6e6704d82a"` to `[deps]`
   - Move `HiGHS = "87dc4568-4c63-4d18-b0c0-bb2238e4078b"` from `[extras]` to `[deps]`
   - Add `PrecompileTools = ">= 1.2"` to `[compat]`
   - Add `HiGHS = "1"` to `[compat]`
   - Keep `HiGHS` in `[extras]` (Julia allows a package to appear in both `[deps]` and `[extras]`) AND in `[targets].test`

2. Edit `/home/rogerio/git/sddp-lab/src/SDDPlab.jl`:
   - Add `using PrecompileTools` after the existing `using` statements (after line ~66)
   - At the very end of the module (before the final `end`), add:
     ```julia
     @compile_workload begin
         include("precompile_workload.jl")
     end
     ```

3. Create `/home/rogerio/git/sddp-lab/src/precompile_workload.jl`:
   ```julia
   # PrecompileTools workload for SDDPlab
   # This file is included inside @compile_workload in SDDPlab.jl
   # The workload exercises the hot SDDP training path to cache native code.
   # See ticket-052 for the actual workload implementation.
   ```

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/Project.toml`
- `/home/rogerio/git/sddp-lab/src/SDDPlab.jl`

### Key Files to Create

- `/home/rogerio/git/sddp-lab/src/precompile_workload.jl`

### Patterns to Follow

- Follow the existing `using .SubModule:` pattern in `SDDPlab.jl` for the PrecompileTools import (but PrecompileTools is a top-level package, so use `using PrecompileTools` directly)
- The `@compile_workload` block must be inside the `module SDDPlab ... end` scope

### Pitfalls to Avoid

- Do NOT put `using PrecompileTools` outside the module scope
- Do NOT add PrecompileTools to `[extras]` -- it must be in `[deps]` because `@compile_workload` runs during precompilation, not during testing
- HiGHS appearing in both `[deps]` and `[extras]` is valid Julia -- do not remove it from `[extras]` or `[targets]`
- The `@compile_workload` block must come AFTER all `include` and `export` statements, because the workload will call functions defined in the module
- Do NOT include any actual workload code yet -- that is ticket-052's scope

## Testing Requirements

### Unit Tests

- No new unit tests needed for this scaffold ticket

### Integration Tests

- Run the existing test suite with `TEST_FILTER="test-engines"` to verify no regressions from the dependency changes
- Verify `using SDDPlab` works in a fresh Julia session after `Pkg.instantiate()`

### E2E Tests

- Not applicable

## Dependencies

- **Blocked By**: None (all prior epics completed)
- **Blocks**: ticket-052-implement-smart-precompile-workload.md, ticket-053-suppress-sddp-stdout-precompilation.md

## Effort Estimate

**Points**: 2
**Confidence**: High
