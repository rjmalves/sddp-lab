# ticket-022 Implement Thread-Safe SAA Generation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SAA reproducibility with parallel RNG)

## Context

### Background

The SAA (Sample Average Approximation) generation pipeline currently seeds the global RNG via `Random.seed!` and then calls `Random.default_rng()` to produce samples. This works correctly in serial execution but is fundamentally unsafe when SDDP.jl's `Threaded()` parallel scheme is active: multiple threads executing forward passes share the global RNG, leading to data races and non-reproducible results. This ticket makes SAA generation thread-safe by replacing the global RNG usage with an explicit, locally-constructed `MersenneTwister` instance seeded from the study's seed value.

### Relation to Epic

This ticket directly enables correct threaded execution. Ticket-021 adds the `Threaded` parallel scheme struct and wiring, but the actual SAA generation (which feeds the SDDP subproblem parameterization) uses the global RNG. Without this fix, threaded training would produce non-reproducible and potentially corrupted SAA values. This ticket is a prerequisite for ticket-023 (profiling under threading) since profiling results would be meaningless with data-race-affected SAA.

### Current State

- `src/Scenarios/Scenarios.jl` line 59-61: `set_seed!(scenarios)` calls `Random.seed!(scenarios.seed)` -- this mutates the **global** default RNG.
- `src/StochasticProcess/StochasticProcess.jl` lines 52-56: `generate_saa(s, initial_season, N, B)` calls `__generate_saa(Random.default_rng(), s, initial_season, N, B)` -- reads from the global RNG.
- `src/StochasticProcess/naive.jl` lines 100-122: `__generate_saa(rng::AbstractRNG, s::Naive, ...)` accepts an RNG and uses `rand(rng, D, 1)` -- already parameterized by RNG.
- `src/StochasticProcess/autoregressive.jl` lines 214-223: `__generate_saa(rng::AbstractRNG, s::AutoRegressive, ...)` delegates to `__generate_saa(rng, s.noise_model, ...)` -- also parameterized.
- `src/Engines/sddp/build.jl` lines 300-301: The build pipeline calls `set_seed!(scenarios)` then `generate_saa(scenarios, num_stages)` sequentially.
- The `__generate_saa` implementations already accept `rng::AbstractRNG` as first argument -- the plumbing is in place. The only issue is that the public `generate_saa` function and `set_seed!` use the global RNG.

## Specification

### Requirements

1. Modify `generate_saa` in `src/StochasticProcess/StochasticProcess.jl` to accept an optional `rng::AbstractRNG` argument. When provided, use it instead of `Random.default_rng()`.
2. Add a new overload: `generate_saa(s, initial_season, N, B, seed::Integer)` that creates a `MersenneTwister(seed)` and passes it to `__generate_saa`. This is the preferred entry point for reproducible, thread-safe SAA.
3. Modify `generate_saa` in `src/Engines/sddp/build.jl` (line 262-267) to pass the seed from `scenarios.seed` directly into the new `generate_saa` overload, rather than relying on `set_seed!` + global RNG.
4. Remove the call to `set_seed!(scenarios)` from `__generate_subproblem_builder` in `src/Engines/sddp/build.jl` (line 300), replacing it with the seed-passing approach.
5. Keep `set_seed!` as a public function (do not delete it) for backward compatibility, but add a deprecation warning suggesting the seed-passing overload.
6. Ensure that for the same seed, SAA output is bit-identical whether generated with 1 thread or N threads. The SAA itself is generated **before** SDDP.jl starts threaded forward passes, so it is inherently single-threaded. The key is to NOT mutate global state that threads might read.

### Inputs/Props

- `scenarios.seed::Integer` -- the seed value from the JSONC configuration.
- `inflow.stochastic_process::AbstractStochasticProcess` -- the stochastic process to sample.
- `initial_season::Integer`, `num_stages::Integer`, `branchings::Integer` -- SAA dimensions.

### Outputs/Behavior

- `generate_saa` with explicit seed returns the same SAA as the old global-seed approach for the same seed value (reproducibility).
- The global RNG (`Random.default_rng()`) is no longer mutated during model building.
- SDDP.jl's internal RNG usage (for forward pass sampling during training) is unaffected -- SDDP.jl manages its own RNG internally.

### Error Handling

- The `seed` parameter is already validated as a positive integer by the `ScenariosData` constructor (existing validation). No new error handling needed.
- The deprecated `set_seed!` emits `Base.depwarn("set_seed! mutates the global RNG and is not thread-safe. Use generate_saa(s, season, N, B, seed) instead.", :set_seed!)`.

## Acceptance Criteria

1. Given a study with seed=42, when `generate_saa` is called with the seed-passing overload, then the result is bit-identical to calling it with the old global-seed approach using the same seed.
2. Given the build pipeline (`__generate_subproblem_builder`), when it executes, then `Random.default_rng()` is NOT mutated (the global RNG state before and after building is unchanged).
3. Given the same study seed, when SAA is generated multiple times (in separate calls), then results are identical each time (reproducibility).
4. Given a study configured with `Threaded` parallel scheme, when the full pipeline (build -> train -> simulate) is run, then no data race warnings or errors occur related to RNG.
5. Given all existing tests, when the test suite is run, then all tests continue to pass (the new generate_saa overload preserves backward compatibility).
6. Given `set_seed!` is called, when deprecation warnings are enabled, then a deprecation warning is emitted.

## Implementation Guide

### Suggested Approach

**Step 1: Add seed-passing overload to `StochasticProcess.jl`**

In `src/StochasticProcess/StochasticProcess.jl`, after the existing `generate_saa` function (line 56), add:

```julia
function generate_saa(
    s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer,
    seed::Integer
)::Vector{Vector{Vector{Float64}}}
    rng = Random.MersenneTwister(seed)
    return __generate_saa(rng, s, initial_season, N, B)
end
```

**Step 2: Add deprecation warning to `set_seed!`**

In `src/Scenarios/Scenarios.jl`, modify `set_seed!` (lines 59-61):

```julia
function set_seed!(scenarios::ScenariosData)
    Base.depwarn(
        "set_seed! mutates the global RNG and is not thread-safe. " *
        "Pass seed to generate_saa instead.",
        :set_seed!,
    )
    return Random.seed!(scenarios.seed)
end
```

**Step 3: Update build.jl to use seed-passing approach**

In `src/Engines/sddp/build.jl`, in `__generate_subproblem_builder` (around lines 296-302), replace:

```julia
set_seed!(scenarios)
SAA = generate_saa(scenarios, num_stages)
```

with:

```julia
SAA = generate_saa(scenarios, num_stages, scenarios.seed)
```

This requires modifying the `generate_saa` wrapper in `build.jl` (lines 262-267) to accept and forward the seed:

```julia
function generate_saa(scenarios::ScenariosData, num_stages::Integer, seed::Integer)
    inflow = scenarios.inflow.stochastic_process
    initial_season = scenarios.initial_season
    branchings = scenarios.branchings
    return StochasticProcess.generate_saa(inflow, initial_season, num_stages, branchings, seed)
end
```

Keep the old `generate_saa(scenarios, num_stages)` overload for backward compat (it calls `set_seed!` internally, which now has the deprecation warning).

**Step 4: Export the new overload**

The new overload uses the same function name `generate_saa` which is already exported. No export changes needed.

**Step 5: Write tests** (see Testing Requirements).

### Key Files to Modify

| File                                         | Change                                                                                            |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `src/StochasticProcess/StochasticProcess.jl` | Add `generate_saa(s, season, N, B, seed)` overload                                                |
| `src/Scenarios/Scenarios.jl`                 | Add deprecation warning to `set_seed!`                                                            |
| `src/Engines/sddp/build.jl`                  | Replace `set_seed!` + `generate_saa` with seed-passing `generate_saa`; add seed-accepting wrapper |
| `test/test-main.jl`                          | Add reproducibility test                                                                          |
| `test/Scenarios/test-scenariosdata.jl`       | Add unit test for seed-passing SAA                                                                |

### Patterns to Follow

- The `__generate_saa(rng::AbstractRNG, ...)` pattern is already established in both `naive.jl` and `autoregressive.jl`. This ticket just connects the public API to use it with an explicit RNG.
- For deprecation warnings, follow Julia's `Base.depwarn` convention (used in the codebase for `build(study, optimizer)` deprecation).

### Pitfalls to Avoid

- Do NOT change the `__generate_saa` internal implementations in `naive.jl` or `autoregressive.jl` -- they already accept `rng::AbstractRNG` and work correctly.
- Do NOT try to make the SAA generation itself multi-threaded in this ticket. SAA is generated once before SDDP training starts. Parallelizing SAA generation is a separate optimization (ticket-023).
- Do NOT remove `set_seed!` -- mark it deprecated. Existing user code may call it directly.
- Use `MersenneTwister` (not `TaskLocalRNG`) for the explicit RNG. `MersenneTwister` is deterministic for a given seed, well-tested, and does not depend on task/thread identity. `TaskLocalRNG` would give different sequences depending on which task runs the code.
- Verify that `Random.MersenneTwister(seed)` is imported -- `StochasticProcess.jl` already has `using Random` (line 3).

## Testing Requirements

### Unit Tests

In `test/Scenarios/test-scenariosdata.jl` (or a new test file if more appropriate):

1. **Seed-passing SAA reproducibility**: Generate SAA twice with the same seed using the new overload. Verify results are bit-identical (`@test saa1 == saa2`).
2. **Seed-passing matches global-seed**: Generate SAA using `Random.seed!(42); generate_saa(process, season, N, B)` and compare with `generate_saa(process, season, N, B, 42)`. They must be identical.
3. **Different seeds produce different SAA**: Generate SAA with seed 42 and seed 123. Verify results differ (`@test saa1 != saa2`).

### Integration Tests

In `test/test-main.jl`:

1. **Threaded pipeline with seed reproducibility**: Run the full build/train pipeline twice with the same seed and `Threaded` scheme. Verify that SAA values are identical by comparing the model builds (or by extracting SAA values from a modified test helper). This test can be simplified to just verifying the pipeline completes without error, since SAA reproducibility is covered by unit tests.

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-021 (Threaded struct must exist for integration testing)
- **Blocks**: ticket-023

## Effort Estimate

**Points**: 2
**Confidence**: High
