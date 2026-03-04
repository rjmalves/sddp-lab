# ticket-024 Add Distributed Computing Support

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SDDP.Asynchronous distributed correctness)

## Context

### Background

SDDPlab already has an `Asynchronous` struct (defined in `src/Engines/Engines.jl` line 71) and a `generate_parallel_scheme(::Asynchronous)` method (line 367-369 of `src/Engines/sddp/input.jl`) that returns `SDDP.Asynchronous()`. However, there is no validation that distributed workers are actually available when `Asynchronous` is selected, no documentation of worker setup requirements, no helper for data distribution, and no integration test proving it works end-to-end. This ticket hardens the `Asynchronous` scheme with runtime validation, adds a pre-flight check for worker availability, documents the user's responsibility for worker management, and writes an integration test.

### Relation to Epic

This is the final ticket in Epic 04. It completes the parallelization support by ensuring both shared-memory threading (ticket-021) and distributed-memory (this ticket) parallel schemes are fully functional. Where ticket-021 adds the `Threaded` struct, this ticket hardens the existing `Asynchronous` struct that was defined but never tested.

### Current State

- `src/Engines/Engines.jl` line 71: `struct Asynchronous <: ParallelScheme end` -- exists, parameterless.
- `src/Engines/sddp/input.jl` lines 153-155: `Asynchronous(::Dict{String,Any}, ::CompositeException)` constructor -- exists, returns `Asynchronous()`.
- `src/Engines/sddp/input.jl` lines 367-369: `generate_parallel_scheme(::Asynchronous)` returns `SDDP.Asynchronous()` -- exists, no validation.
- `SDDP.Asynchronous()` requires `Distributed.nworkers() > 0` at training time. If no workers are added, SDDP.jl will error internally.
- The `Asynchronous` struct is already constructible from JSONC via `{"kind": "Asynchronous", "params": {}}`. The kind_factory! pipeline handles it.
- No tests exercise `Asynchronous` in any form.
- SDDP.jl's Asynchronous scheme requires that all worker processes have the model, solver, and dependencies loaded via `@everywhere`.

## Specification

### Requirements

1. Add a runtime validation to `generate_parallel_scheme(::Asynchronous)` that checks `Distributed.nworkers() >= 1`. If no workers are available, emit an error message explaining that the user must start Julia with `julia -p N` or call `Distributed.addprocs(N)` before running the pipeline.
2. Add a `@warn` when `Distributed.nworkers() == 1` (only the main process) advising that Asynchronous with 1 worker provides no benefit over Serial.
3. Add `using Distributed` to `src/Engines/Engines.jl` (or add a conditional import to avoid loading Distributed when not needed).
4. Document in the epic overview and in a docstring on `generate_parallel_scheme(::Asynchronous)` that the user is responsible for: (a) starting workers via `julia -p N` or `addprocs()`, (b) loading SDDPlab and the solver on all workers via `@everywhere using SDDPlab, GLPK`, (c) ensuring all workers have access to the input data files.
5. Add a unit test verifying the error message when no workers are available.
6. Add a conditional integration test that runs the full pipeline with `Asynchronous` only when `Distributed.nworkers() > 1` (skipped in standard CI where workers are not spawned).

### Inputs/Props

- JSONC configuration: `"parallel_scheme": {"kind": "Asynchronous", "params": {}}` in both policy and simulation sections.
- Distributed.jl: workers must be set up by the user before calling `build`/`train`/`simulate`.

### Outputs/Behavior

- `generate_parallel_scheme(::Asynchronous)` returns `SDDP.Asynchronous()` when workers are available.
- Clear error message when no workers are available.
- Warning when only 1 worker is present.
- Docstring documenting setup requirements.

### Error Handling

- When `Distributed.nworkers() < 1` (impossible in practice since nworkers() >= 1 always, but the effective condition is nworkers() == 1 meaning only the master), throw an `ErrorException` with message: "Asynchronous parallel scheme requires distributed workers. Start Julia with 'julia -p N' or call 'Distributed.addprocs(N)' before running the pipeline."
- Actually, `Distributed.nworkers()` returns 1 when no `addprocs` has been called (the master counts as 1 worker). SDDP.jl's `Asynchronous` scheme needs at least 2 processes (master + 1 worker) to be useful, but it may still work with just the master. The validation should check `Distributed.nprocs() == 1` (only master, no workers added) and warn, not error. This allows the pipeline to proceed but alerts the user.

## Acceptance Criteria

1. Given a JSONC file with `"parallel_scheme": {"kind": "Asynchronous", "params": {}}`, when `SDDPEngine` is constructed from dict, then `SDDPPolicyTaskDefinition.parallel_scheme` is an `Asynchronous` instance (this already works, just verify it).
2. Given `Distributed.nprocs() == 1` (no workers added), when `generate_parallel_scheme(Asynchronous())` is called, then a warning is emitted containing "Asynchronous parallel scheme requested but no distributed workers are available".
3. Given `generate_parallel_scheme(Asynchronous())`, when called, then it returns a `SDDP.Asynchronous` instance.
4. Given a Julia session with `Distributed.addprocs(2)` and `@everywhere using SDDPlab, GLPK`, when the full pipeline (build -> train -> simulate) is run with `Asynchronous` scheme, then it completes without error.
5. Given the docstring on `generate_parallel_scheme(::Asynchronous)`, when viewed via `?generate_parallel_scheme`, then it explains the worker setup requirements.
6. Given all existing tests, when the test suite is run, then all tests continue to pass.

## Implementation Guide

### Suggested Approach

**Step 1: Add Distributed import**

In `src/Engines/Engines.jl`, add `using Distributed` to the imports (after line 15). Since `Distributed` is a stdlib module, it has negligible load cost.

**Step 2: Update `generate_parallel_scheme(::Asynchronous)`**

In `src/Engines/sddp/input.jl`, replace the existing method (lines 367-369):

```julia
"""
    generate_parallel_scheme(::Asynchronous) -> SDDP.Asynchronous

Generate the SDDP.jl `Asynchronous()` parallel scheme for distributed training.

# Worker Setup Requirements

The user is responsible for setting up distributed workers before calling
`train` or `simulate` with the `Asynchronous` scheme:

1. Start Julia with `julia -p N` or call `Distributed.addprocs(N)`.
2. Load SDDPlab and the solver on all workers:
   `@everywhere using SDDPlab, GLPK`
3. Ensure all workers have access to the input data files (shared filesystem
   or distributed storage).
"""
function generate_parallel_scheme(::Asynchronous)::SDDP.AbstractParallelScheme
    if Distributed.nprocs() == 1
        @warn(
            "Asynchronous parallel scheme requested but no distributed workers " *
            "are available. Use 'julia -p N' or 'Distributed.addprocs(N)' to " *
            "add workers. Running on the master process only.",
        )
    end
    return SDDP.Asynchronous()
end
```

**Step 3: Add unit test for warning**

In a **new file** `test/Engines/test-distributed.jl` (do NOT add to `test-engines.jl` — adding to large existing test files has caused SIGABRTs):

```julia
@testset "asynchronous-parallel-scheme-warning" begin
    # In standard test environment, nprocs() == 1
    # Verify warning is emitted
    @test_warn r"Asynchronous parallel scheme requested" begin
        Engines.generate_parallel_scheme(Engines.Asynchronous())
    end
end
```

**Step 4: Add conditional integration test**

In `test/test-main.jl`, add a test that is skipped when no workers are available:

```julia
@testset "1dtoy-pipeline-asynchronous" begin
    if Distributed.nprocs() == 1
        @info "Skipping Asynchronous integration test: no distributed workers available"
        @test_skip true
    else
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Asynchronous(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def, sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("GLPK", Dict{String,Any}())
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end
end
```

**Step 5: Verify existing `Asynchronous` construction tests**

Confirm that existing engine construction tests already cover `Asynchronous` via the kind_factory! pipeline. If not, add a test similar to the `Threaded` tests from ticket-021.

### Key Files to Modify

| File                               | Change                                                                          |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `src/Engines/Engines.jl`           | Add `using Distributed`                                                         |
| `src/Engines/sddp/input.jl`        | Add docstring and runtime warning to `generate_parallel_scheme(::Asynchronous)` |
| `test/Engines/test-distributed.jl` | New file: unit tests for Asynchronous warning and construction                  |
| `test/test-main.jl`                | Add conditional integration test for Asynchronous pipeline                      |

### Patterns to Follow

- Follow the same `@warn` pattern used for `Threaded` in ticket-021 (emit warning in `generate_parallel_scheme`, not in the constructor).
- Follow the integration test pattern from `test/test-main.jl` for pipeline tests.
- Use `@test_skip` for tests that require infrastructure not available in standard CI.

### Pitfalls to Avoid

- Do NOT call `Distributed.addprocs()` from within SDDPlab code. Worker management is the user's responsibility. SDDP.jl's documentation is clear about this: the user sets up workers, loads packages on them, then runs training.
- Do NOT throw an error when no workers are available -- just warn. SDDP.jl's `Asynchronous()` will fall back gracefully to running on the master process. Throwing would break pipelines where the user legitimately wants to test the config without workers.
- `Distributed.nprocs()` returns 1 when only the master process exists. `Distributed.nworkers()` also returns 1 in this case (the master acts as a worker). The correct check is `Distributed.nprocs() == 1`.
- Adding `using Distributed` at module load time is acceptable because `Distributed` is a Julia stdlib and is extremely lightweight. It does NOT spawn workers -- it just makes the API available.
- The simulation test uses `Engines.Serial()` for `sim_def.parallel_scheme` intentionally. Running distributed simulation requires a different test setup (all workers need the trained policy). Keep the integration test focused on distributed training.

## Testing Requirements

### Unit Tests

In a **separate test file** `test/Engines/test-distributed.jl` (do NOT add to `test-engines.jl` — see Test Execution Protocol in master plan):

1. **Asynchronous from valid dict**: Given `Dict("kind" => "Asynchronous", "params" => Dict{String,Any}())` in a policy dict, construct `SDDPPolicyTaskDefinition` and verify `policy.parallel_scheme isa Engines.Asynchronous`.
2. **generate_parallel_scheme(Asynchronous()) returns correct type**: Verify it returns a `SDDP.Asynchronous` instance.
3. **Warning when no workers**: In standard test environment (nprocs == 1), verify that `generate_parallel_scheme(Asynchronous())` emits a warning matching "Asynchronous parallel scheme requested".

### Integration Tests

In `test/test-main.jl`:

1. **Conditional Asynchronous pipeline**: As described in Step 4 above. Skipped when `Distributed.nprocs() == 1`.

### Running Tests

Follow the **Test Execution Protocol** from `00-master-plan.md`:

```bash
# Run only the new distributed test file (with timeout)
export TEST_FILTER="test-distributed" && julia --project -e 'using Pkg; Pkg.test()'
# Bash timeout: 120000 ms

# Run integration tests if pipeline test was added to test-main
export TEST_FILTER="test-main" && julia --project -e 'using Pkg; Pkg.test()'
# Bash timeout: 180000 ms
```

**NEVER** run the full test suite without `TEST_FILTER`. Always set the Bash tool timeout.

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-023 (optimized build performance benefits distributed execution)
- **Blocks**: None (this is the last ticket in Epic 04)

## Effort Estimate

**Points**: 2
**Confidence**: High
