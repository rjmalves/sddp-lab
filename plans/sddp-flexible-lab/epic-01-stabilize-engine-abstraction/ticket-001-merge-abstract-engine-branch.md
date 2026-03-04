# ticket-001 Merge abstract-engine Branch into Main

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (straightforward merge operation)

## Context

### Background

The `abstract-engine` branch on `origin/abstract-engine` contains a major architectural refactoring of SDDPlab.jl. It replaces the monolithic `Main.jl` + `Tasks/` + `Outputs/` + `Algorithm/` modules with a clean Engine abstraction layer: `Lab/` (abstract types and interface), `Engines/` (concrete SDDPEngine), and `study.jl` (entry point). The branch has 13 commits ahead of `main` and modifies ~100 files with +2784/-4485 lines changed. Tests on the branch are passing for the `1dtoy` example case.

### Relation to Epic

This is the first ticket in Epic 01 (Stabilize Engine Abstraction). All subsequent work builds on the code from this branch being present in `main`.

### Current State

- `main` branch has the old architecture: `Core/`, `Algorithm/`, `Tasks/`, `Outputs/`, `Main.jl`
- `origin/abstract-engine` branch has the new architecture: `Lab/`, `Engines/`, `study.jl`
- The branch was created from `main` and has one merge commit from `main` already (`ef1cb2b`)
- Key structural changes:
  - `src/Core/` renamed to `src/Lab/` with new abstract types (Engine, Model, PolicyTaskDefinition, etc.)
  - `src/Algorithm/` removed entirely (scenario graph now in `src/Scenarios/graph.jl`)
  - `src/Tasks/` removed (functionality moved to `src/Engines/sddp/`)
  - `src/Outputs/` removed (functionality moved to `src/Engines/sddp/save_policy.jl` and `save_simulation.jl`)
  - `src/Main.jl` removed (replaced by `src/study.jl`)
  - New `src/Engines/Engines.jl` with SDDPEngine, Convergence, StoppingCriteria, ParallelScheme, RiskMeasure types
  - Example `1dtoy` updated with new `graph.jsonc`, `scenarios.jsonc` format and restructured `main.jsonc`

## Specification

### Requirements

1. Merge the `abstract-engine` branch into `main` cleanly
2. Resolve any merge conflicts (expected to be minimal since `abstract-engine` includes a merge from `main`)
3. Verify that all existing tests pass after the merge
4. Verify that the `1dtoy` example case runs end-to-end (read -> build -> train -> simulate -> save)

### Inputs/Props

- Source branch: `origin/abstract-engine`
- Target branch: `main`

### Outputs/Behavior

- `main` branch contains all code from `abstract-engine`
- The old modules (`Algorithm/`, `Tasks/`, `Outputs/`, `Main.jl`, `Core/`) are removed
- The new modules (`Lab/`, `Engines/`, `study.jl`) are present
- All tests pass

### Error Handling

- If merge conflicts arise, resolve them by preferring the `abstract-engine` version for files that were restructured (since the old files are deleted)
- If tests fail after merge, investigate and fix before proceeding

## Acceptance Criteria

- [ ] Given the `abstract-engine` branch exists on `origin`, when it is merged into `main`, then the merge completes without unresolved conflicts
- [ ] Given the merge is complete, when `julia --project -e 'using Pkg; Pkg.test()'` is run, then all tests pass
- [ ] Given the merge is complete, when the `1dtoy` example is run via `read_study` -> `build` -> `train` -> `simulate` -> `save_simulation`, then no errors occur
- [ ] Given the merge is complete, when `src/Algorithm/` is checked, then it does not exist (removed)
- [ ] Given the merge is complete, when `src/Tasks/` is checked, then it does not exist (removed)
- [ ] Given the merge is complete, when `src/Engines/Engines.jl` is checked, then it exists and defines `SDDPEngine`

## Implementation Guide

### Suggested Approach

1. Create a local branch from `main` for the merge work:
   ```bash
   git checkout main
   git checkout -b merge-abstract-engine
   ```
2. Merge the remote abstract-engine branch:
   ```bash
   git merge origin/abstract-engine
   ```
3. Resolve any conflicts. Expected conflict-free since `abstract-engine` already merged `main` at commit `ef1cb2b`.
4. Run tests:
   ```bash
   julia --project -e 'using Pkg; Pkg.test()'
   ```
5. If tests pass, merge `merge-abstract-engine` into `main`.

### Key Files to Modify

- No manual modifications expected -- this is a merge operation
- If conflicts arise, they would most likely be in:
  - `src/SDDPlab.jl` (module includes changed)
  - `Project.toml` (dependency list)
  - `test/runtests.jl` (test includes changed)

### Patterns to Follow

- Use `git merge` (not rebase) to preserve the branch history
- The commit message should reference the architectural change: "Merge abstract-engine: introduce Engine abstraction layer"

### Pitfalls to Avoid

- Do not force-push to `main`
- Do not delete the `abstract-engine` branch until all Epic 01 tickets are complete (for reference)
- Do not attempt to rewrite history on either branch

## Testing Requirements

### Unit Tests

- All existing unit tests from `abstract-engine` must pass after merge

### Integration Tests

- The full pipeline test in `test/test-main.jl` must pass (read_study -> build -> train -> save_policy -> load_policy -> simulate -> save_simulation)
- The study tests in `test/test-study.jl` must pass

### E2E Tests

- N/A (covered by integration tests above)

## Dependencies

- **Blocked By**: None
- **Blocks**: ticket-002, ticket-003, ticket-004, ticket-005

## Effort Estimate

**Points**: 2
**Confidence**: High
