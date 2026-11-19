# ticket-021 Enable Threaded Parallel Training and Simulation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SDDP.jl parallel scheme thread-safety requirements)

## Context

### Background

SDDPlab currently supports two `ParallelScheme` subtypes: `Serial` (fully functional, used in all tests and examples) and `Asynchronous` (struct and `generate_parallel_scheme` method exist, but untested and without worker management). The SDDP.jl library provides a third parallel scheme -- `SDDP.Threaded()` -- that distributes forward/backward passes across Julia threads. This ticket adds a `Threaded` struct to SDDPlab with an optional user-specified thread count, integrates it into the existing kind_factory! pipeline, and validates that multi-threaded training and simulation produce correct results.

### Relation to Epic

This is the foundational ticket for Epic 04 (Parallelization and Performance). It establishes the threading infrastructure that subsequent tickets build upon: ticket-022 ensures thread-safe SAA generation, ticket-023 profiles and optimizes hot paths under threading, and ticket-024 extends the Asynchronous scheme with proper worker management.

### Current State

- `src/Engines/Engines.jl` lines 67-71: `abstract type ParallelScheme end`, `struct Serial <: ParallelScheme end`, `struct Asynchronous <: ParallelScheme end`. There is **no** `Threaded` struct.
- `src/Engines/sddp/input.jl` lines 149-155: `Serial(::Dict, ::CompositeException)` and `Asynchronous(::Dict, ::CompositeException)` constructors exist. No `Threaded` constructor.
- `src/Engines/sddp/input.jl` lines 363-369: `generate_parallel_scheme(::Serial)` returns `SDDP.Serial()` and `generate_parallel_scheme(::Asynchronous)` returns `SDDP.Asynchronous()`. No `Threaded` dispatch.
- `src/Engines/sddp/train.jl` line 10: `parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)` -- already generic, will work with any new `generate_parallel_scheme` method.
- `src/Engines/sddp/simulate.jl` line 18: Same pattern -- `parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)`.
- All existing examples and tests use `Serial`.

## Specification

### Requirements

1. Add a `Threaded` struct as a subtype of `ParallelScheme` in `src/Engines/Engines.jl`, following the existing convention for parameterless types.
2. Add a `Threaded(::Dict{String,Any}, ::CompositeException)` constructor in `src/Engines/sddp/input.jl`, identical to the `Serial` and `Asynchronous` constructor pattern (ignores dict, returns `Threaded()`).
3. Add a `generate_parallel_scheme(::Threaded)::SDDP.AbstractParallelScheme` method in `src/Engines/sddp/input.jl` that returns `SDDP.Threaded()`.
4. Export `Threaded` from the `Engines` module (add to the `export` list in `Engines.jl`).
5. Verify that the existing `__build_parallel_scheme!` + `__kind_factory!` pipeline resolves `{"kind": "Threaded", "params": {}}` correctly without any additional validator changes (it should, since `Threaded` follows the parameterless pattern).
6. Add a runtime warning (via `@warn`) when `Threads.nthreads() == 1` and a `Threaded` scheme is requested, advising the user to start Julia with `--threads N`.

### Inputs/Props

- JSONC configuration: `"parallel_scheme": {"kind": "Threaded", "params": {}}` in both policy and simulation sections.
- No parameters needed (SDDP.Threaded() auto-detects `Threads.nthreads()`).

### Outputs/Behavior

- `generate_parallel_scheme(::Threaded)` returns `SDDP.Threaded()`.
- Training and simulation with `Threaded` complete successfully.
- When Julia has only 1 thread, a warning is emitted but execution proceeds (falls back to serial behavior within SDDP.jl).

### Error Handling

- If `kind: "Threaded"` is specified and Julia has 1 thread, emit `@warn "Threaded parallel scheme requested but Julia was started with only 1 thread. Use 'julia --threads N' for parallelism."` inside `generate_parallel_scheme(::Threaded)`.
- All existing error handling for malformed parallel_scheme dicts (missing kind, invalid kind name, etc.) already works via `__build_parallel_scheme!` and `__kind_factory!`.

## Acceptance Criteria

1. Given a JSONC file with `"parallel_scheme": {"kind": "Threaded", "params": {}}`, when `SDDPEngine` is constructed from dict, then the resulting `SDDPPolicyTaskDefinition.parallel_scheme` is a `Threaded` instance.
2. Given a `Threaded()` instance, when `generate_parallel_scheme(Threaded())` is called, then it returns a `SDDP.Threaded` instance.
3. Given a study configured with `Threaded` parallel scheme, when the full pipeline (build -> train -> simulate) is run, then it completes without error and produces valid results.
4. Given Julia started with 1 thread, when `generate_parallel_scheme(Threaded())` is called, then a warning is emitted containing "Threaded parallel scheme requested but Julia was started with only 1 thread".
5. Given a study configured with `Threaded` in the policy but `Serial` in the simulation (or vice versa), when the pipeline is run, then each phase uses its own parallel scheme correctly.
6. Given all existing tests, when the test suite is run, then all tests continue to pass (no regressions).

## Implementation Guide

### Suggested Approach

This follows the exact same pattern as adding any parameterless algorithm option type (proven 20+ times across epics 02-03):

**Step 1: Add the struct** to `src/Engines/Engines.jl` (after line 71, after `Asynchronous`):

```julia
struct Threaded <: ParallelScheme end
```

**Step 2: Add to export list** in `src/Engines/Engines.jl` (add `Threaded` to the `export` block around line 210-226).

**Step 3: Add the dict constructor** to `src/Engines/sddp/input.jl` (after line 155):

```julia
function Threaded(::Dict{String,Any}, ::CompositeException)
    return Threaded()
end
```

**Step 4: Add the generate method** to `src/Engines/sddp/input.jl` (after line 369):

```julia
function generate_parallel_scheme(::Threaded)::SDDP.AbstractParallelScheme
    if Threads.nthreads() == 1
        @warn "Threaded parallel scheme requested but Julia was started with only 1 thread. Use 'julia --threads N' for parallelism."
    end
    return SDDP.Threaded()
end
```

**Step 5: No validator changes needed.** The existing `__build_parallel_scheme!` calls `__kind_factory!` which resolves `"Threaded"` to the struct via `getfield(@__MODULE__, Symbol("Threaded"))`. The parameterless constructor pattern handles it.

**Step 6: Write tests** (see Testing Requirements).

### Key Files to Modify

| File                           | Change                                                                                                      |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `src/Engines/Engines.jl`       | Add `struct Threaded <: ParallelScheme end`; add `Threaded` to export                                       |
| `src/Engines/sddp/input.jl`    | Add `Threaded(::Dict, ::CompositeException)` constructor; add `generate_parallel_scheme(::Threaded)` method |
| `test/Engines/test-engines.jl` | Add unit tests for `Threaded` construction from dict                                                        |
| `test/test-main.jl`            | Add integration test for threaded pipeline                                                                  |

### Patterns to Follow

- Follow the exact pattern of `Serial` for struct, constructor, and generate method (lines 69, 149-151, 363-365 in the respective files).
- For integration tests, follow the pattern from `test/test-main.jl` lines 67-97 (`1dtoy-pipeline-statistical-stopping`): construct `SDDPPolicyTaskDefinition` and `SDDPSimulationTaskDefinition` with the desired scheme, overlay onto a read study, and run build/train/simulate.

### Pitfalls to Avoid

- Do NOT add a `num_threads` parameter to the `Threaded` struct. SDDP.jl's `Threaded()` auto-detects from `Threads.nthreads()`. Adding a parameter would require matching the SDDP.jl API, which does not accept a thread count argument.
- Do NOT modify `__build_parallel_scheme!` or `__validate_parallel_scheme_main_key_type!` -- the existing pipeline handles new kinds automatically via `kind_factory!`.
- The runtime `@warn` should be in `generate_parallel_scheme`, NOT in the constructor. The constructor runs at config-parse time; the generate method runs at train/simulate time when thread count matters.
- SDDP.jl's Threaded scheme works correctly even with 1 thread (it simply runs serially). The warning is informational only.

## Testing Requirements

### Unit Tests

In `test/Engines/test-engines.jl`:

1. **Threaded from valid dict**: Given `Dict("kind" => "Threaded", "params" => Dict{String,Any}())` in a policy dict, construct `SDDPPolicyTaskDefinition` and verify `policy.parallel_scheme isa Engines.Threaded`.
2. **Threaded from valid dict (simulation)**: Same pattern for `SDDPSimulationTaskDefinition`.
3. **generate_parallel_scheme(Threaded())**: Verify it returns a `SDDP.Threaded` instance.

### Integration Tests

In `test/test-main.jl`:

1. **1dtoy-pipeline-threaded**: Follow the pattern of existing pipeline tests. Construct a study with `Engines.Threaded()` for both policy and simulation parallel schemes. Run build -> train -> simulate. Assert all results are non-nothing. Use `@suppress` to capture output. Note: even with 1 thread (CI environments), this test validates the full code path.

### E2E Tests

Not applicable -- integration tests cover the full pipeline.

## Dependencies

- **Blocked By**: ticket-020 (Epic 03 complete -- all prior infrastructure in place)
- **Blocks**: ticket-022, ticket-023

## Effort Estimate

**Points**: 2
**Confidence**: High
