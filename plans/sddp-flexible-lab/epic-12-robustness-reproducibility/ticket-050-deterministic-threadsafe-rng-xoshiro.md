# ticket-050 Deterministic Thread-Safe RNG with Xoshiro

## Context

### Background

The SAA (Sample Average Approximation) generation in `src/StochasticProcess/StochasticProcess.jl` uses `Random.MersenneTwister(seed)` (line 99) for the seeded overload. The per-state seed derivation in `src/Engines/sddp/build.jl` (line 717) uses a linear offset: `state_seed = seed + (state - 1) * 7919`. Both of these have issues: MersenneTwister is slower than Xoshiro (Julia's default RNG since 1.7), the linear offset can produce correlated streams for certain seed values, and the deprecated `set_seed!` function (lines 199-206 in `Scenarios.jl`) still exists in the codebase.

### Relation to Epic

This is an independent reproducibility and performance improvement in Epic 12. It modernizes the RNG infrastructure and improves the determinism guarantees for parallel SAA generation.

### Current State

- `StochasticProcess.jl` line 99: `rng = Random.MersenneTwister(seed)` in the seeded `generate_saa` overload
- `StochasticProcess.jl` line 63: `Random.default_rng()` in the unseeded overload (uses Julia's task-local Xoshiro)
- `build.jl` line 717: `state_seed = seed + (state - 1) * 7919` for per-Markov-state seed derivation
- `Scenarios.jl` lines 199-206: deprecated `set_seed!` function that mutates global RNG with `Random.seed!`
- `Scenarios.jl` line 322: `set_seed!` is exported
- `test/Scenarios/test-scenariosdata.jl` lines 238-242: test for `set_seed!` deprecation warning
- `build.jl` line 700-723: two `generate_saa` overloads, the seeded one passes `seed + (state-1)*7919` per state

## Specification

### Requirements

1. Replace `Random.MersenneTwister(seed)` with `Random.Xoshiro(seed)` in the seeded `generate_saa` overload (`StochasticProcess.jl` line 99)
2. Implement a composed-seed approach for per-state seed derivation: replace `seed + (state - 1) * 7919` with `hash(seed, hash(state))` in `build.jl` line 717. This produces well-distributed, non-correlated seeds using Julia's built-in `hash` function.
3. Remove the deprecated `set_seed!` function entirely from `Scenarios.jl` (lines 199-206)
4. Remove `set_seed!` from the export list in `Scenarios.jl` (line 322)
5. Remove the `set_seed!` deprecation test from `test/Scenarios/test-scenariosdata.jl` (lines 238-242)
6. Add new tests verifying:
   - Xoshiro reproducibility: same seed produces same SAA
   - Composed seed distribution: `hash(seed, hash(state))` produces different values for different states
   - Global RNG isolation: the seeded overload does NOT mutate global RNG state
   - Thread safety: concurrent calls with different seeds produce correct, independent results

### Inputs/Props

- `seed::Integer` from `ScenariosData`
- `state::Int` (Markov state index)

### Outputs/Behavior

- `generate_saa(process, initial_season, N, B, seed)` uses `Xoshiro(seed)` instead of `MersenneTwister(seed)`
- Per-state seeds use `hash(seed, hash(state))` instead of `seed + (state-1) * 7919`
- `set_seed!` no longer exists
- SAA output is deterministic for a given seed, independent of thread count

### Error Handling

- If `hash` returns a negative integer (which is valid in Julia), it is passed directly to `Xoshiro` which accepts any `Integer` seed -- no special handling needed
- If `seed` is 0, the behavior is well-defined (Xoshiro handles seed=0 correctly)

## Acceptance Criteria

- [ ] Given `generate_saa(process, 1, 10, 5, 42)` called twice in the same Julia session, when results are compared, then they are identical (Xoshiro reproducibility)
- [ ] Given `generate_saa(process, 1, 10, 5, 42)` and `generate_saa(process, 1, 10, 5, 43)`, when results are compared, then they are different (seed sensitivity)
- [ ] Given `Random.seed!(999); ref = rand(); Random.seed!(999); generate_saa(process, 1, 10, 5, 42); observed = rand()`, when `ref` and `observed` are compared, then `ref == observed` (global RNG not mutated)
- [ ] Given `hash(42, hash(1))` and `hash(42, hash(2))`, when compared, then they are different (composed seed produces distinct per-state seeds)
- [ ] Given a search for `set_seed!` in `src/Scenarios/Scenarios.jl`, when the search completes, then no definition or export of `set_seed!` is found
- [ ] Given a search for `MersenneTwister` in `src/StochasticProcess/StochasticProcess.jl`, when the search completes, then no occurrences are found (replaced by Xoshiro)

## Implementation Guide

### Suggested Approach

1. In `src/StochasticProcess/StochasticProcess.jl`, replace line 99:

   ```julia
   # Before:
   rng = Random.MersenneTwister(seed)
   # After:
   rng = Random.Xoshiro(seed)
   ```

2. In `src/Engines/sddp/build.jl`, replace line 717:

   ```julia
   # Before:
   state_seed = seed + (state - 1) * 7919
   # After:
   state_seed = hash(seed, hash(state))
   ```

3. In `src/Scenarios/Scenarios.jl`:
   - Delete the `set_seed!` function (lines 199-206 including the docstring at lines 190-198)
   - Remove `set_seed!` from the export list (line 322)

4. In `test/Scenarios/test-scenariosdata.jl`:
   - Delete the `"set-seed-emits-deprecation-warning"` testset (lines 238-242)
   - Add new testsets for Xoshiro reproducibility and composed seed

5. Add Xoshiro-specific tests in `test/Scenarios/test-scenariosdata.jl` or a new `test/StochasticProcess/test-rng.jl`:

   ```julia
   @testset "xoshiro-reproducibility" begin
       saa1 = StochasticProcess.generate_saa(process, 1, 10, 5, 42)
       saa2 = StochasticProcess.generate_saa(process, 1, 10, 5, 42)
       @test saa1 == saa2
   end

   @testset "composed-seed-distinct" begin
       seed = 42
       s1 = hash(seed, hash(1))
       s2 = hash(seed, hash(2))
       @test s1 != s2
       saa1 = StochasticProcess.generate_saa(process, 1, 10, 5, s1)
       saa2 = StochasticProcess.generate_saa(process, 1, 10, 5, s2)
       @test saa1 != saa2
   end
   ```

### Key Files to Modify

- `src/StochasticProcess/StochasticProcess.jl` -- line 99: `MersenneTwister` to `Xoshiro`
- `src/Engines/sddp/build.jl` -- line 717: linear offset to `hash` composed seed
- `src/Scenarios/Scenarios.jl` -- delete `set_seed!` (lines 190-206), remove from exports (line 322)
- `test/Scenarios/test-scenariosdata.jl` -- delete `set_seed!` test (lines 238-242), add Xoshiro tests

### Patterns to Follow

- The existing `"seed-passing-reproducibility"` test (lines 188-196 of `test-scenariosdata.jl`) is the pattern for new reproducibility tests
- The existing `"global-rng-not-mutated-by-seed-passing-overload"` test (lines 224-236) is the pattern for global RNG isolation tests

### Pitfalls to Avoid

- Do NOT change the unseeded `generate_saa` overload (line 60-64) -- it already uses `Random.default_rng()` which is Xoshiro
- `hash` returns `UInt64` on 64-bit systems -- `Xoshiro` accepts any `Integer` including `UInt64`, so no conversion needed
- The existing `"seed-passing-reproducibility"` test (line 188-196) will now produce DIFFERENT values than before (Xoshiro vs MersenneTwister produce different sequences for the same seed). This is expected and the test should still pass (it tests self-consistency, not specific values).
- The `"different-seeds-produce-different-saa"` test (lines 214-222) should still pass
- Do NOT remove the `"no-seed-overload-reproducible-with-fixed-global-seed"` test -- it tests the unseeded overload which is unchanged
- The composed seed change means existing trained policies (`.cuts.json` files) will produce different simulation results if retrained from the same config. This is a known breaking change and should be documented.

### Out of Scope

- Changing SDDP.jl's internal RNG for training/simulation forward passes (SDDP.jl manages its own RNG)
- Adding per-thread RNG for parallel training (SDDP.jl handles this internally)
- Modifying the `generate_saa` overload that takes no seed

## Testing Requirements

### Unit Tests

- `"xoshiro-reproducibility"` -- same seed produces identical SAA
- `"xoshiro-different-seeds"` -- different seeds produce different SAA
- `"composed-seed-distinct-states"` -- `hash(seed, hash(1))` != `hash(seed, hash(2))`
- `"composed-seed-reproducible"` -- same `(seed, state)` pair always produces same composed seed
- `"global-rng-isolation"` -- seeded `generate_saa` does not mutate global RNG
- `"set-seed-removed"` -- verify `set_seed!` is not exported (test via `isdefined(Scenarios, :set_seed!)` returning `false` or the symbol being unexported)

### Integration Tests

- Build `1dtoy`, train 3 iterations, simulate -- verify completion (tests the composed seed in the full pipeline)

### E2E Tests

- None required beyond the integration test

## Dependencies

- **Blocked By**: None (independent)
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: High
