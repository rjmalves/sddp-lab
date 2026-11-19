# ticket-023 Profile and Optimize Model Building Hot Paths

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None

## Context

### Background

The model building pipeline in SDDPlab involves several steps: graph construction, SAA generation, subproblem builder creation (which includes adding system elements, uncertainty constraints, load balances, objectives, and parameterization for each node). For small examples (1dtoy, 1dsin, 4ree), build times are negligible, but as the system grows (more hydros, thermals, buses, lines, and longer horizons), the build step can become a bottleneck. This ticket establishes a profiling baseline for model building, identifies the top allocation and time hotspots, and applies targeted optimizations to reduce build time. The target is at least 2x speedup on the larger example cases (4ree) and demonstrable allocation reduction.

### Relation to Epic

This ticket completes the performance portion of Epic 04. With threading (ticket-021) and thread-safe SAA (ticket-022) in place, this ticket profiles the actual hot paths under both serial and threaded execution, optimizes them, and documents the performance characteristics. Ticket-024 (distributed computing) benefits from any optimizations made here since faster per-node model building reduces distributed overhead.

### Current State

- `src/Engines/sddp/build.jl`: The `__generate_subproblem_builder` function (lines 293-329) is called once. It generates SAA and returns a closure `fun_sp_build` that is called once per graph node by `SDDP.PolicyGraph`.
- `fun_sp_build` calls: `add_system_elements!(m, system)`, `add_uncertainties!(m, scenarios, node)`, `__add_load_balance!(m, files, node, s_gen)`, `SDDP.parameterize(m, ...)`, `add_system_objective!(m, system)`.
- `add_system_elements!(m, ::SystemData)` (line 163-170) dispatches to individual element adders: buses, lines, thermals, hydros, hydro_balance.
- SAA generation uses `rand(rng, D, 1)` inside nested loops (line 116-117 of naive.jl) -- potential allocation hotspot from creating `SklarDist` per season.
- `__add_load_balance!` (lines 332-369 of build.jl) re-extracts entities from the system for every node call, repeating work that could be precomputed.
- No profiling data currently exists. No benchmarks are defined.

## Specification

### Requirements

1. Create a benchmark script `benchmark/bench_build.jl` that measures wall-clock time and allocations for `Lab.build(engine, files)` on each example case (1dtoy, 1dsin, 1dsin_ar, 4ree). Record baseline numbers.
2. Profile the build pipeline using `Profile.@profile` and identify the top 5 time-consuming call sites.
3. Profile allocations using `--track-allocation=user` or `@allocated` macros. Identify the top 5 allocation sites.
4. Optimize the identified hotspots. Specific optimization targets (to be confirmed by profiling):
   a. **Precompute entity lookups**: In `fun_sp_build`, entity vectors (hydros, thermals, buses, lines) are re-extracted from `SystemData` every time `__add_load_balance!` is called per node. Move these lookups into the closure's captured scope (precompute once in `__generate_subproblem_builder`).
   b. **Precompute bus-entity mappings**: The load balance constraint uses list comprehensions with `if` filters (e.g., `j for j in 1:num_hydros if hydros_entities[j].bus_id == bus_ids[n]`). Precompute a `Dict{Integer, Vector{Integer}}` mapping bus_id to entity indices once, then use direct lookup.
   c. **Reduce SAA allocations**: The `__generate_saa` inner loop allocates `rand(rng, D, 1)` as a matrix then adds it with `.+=`. Use `rand!(rng, D, buffer)` with a preallocated buffer instead.
   d. **Cache SklarDist construction**: In `__build_mvdist` (naive.jl line 131-140), `SklarDist` is rebuilt for each season from scratch. If the same season appears for multiple nodes, cache the distribution.
5. After optimization, re-run the benchmark and document speedup and allocation reduction.
6. Record benchmark results in a `benchmark/RESULTS.md` file with before/after numbers.

### Inputs/Props

- Example cases: `example/1dtoy`, `example/1dsin`, `example/1dsin_ar`, `example/4ree`.
- Profiling tools: `Profile.jl`, `BenchmarkTools.jl` (`@btime`, `@benchmark`).

### Outputs/Behavior

- `benchmark/bench_build.jl` script that can be run to produce timing/allocation data.
- `benchmark/RESULTS.md` documenting baseline and optimized performance.
- Optimized code in `build.jl` and potentially `naive.jl`.
- All existing tests pass with identical results (optimizations must not change behavior).

### Error Handling

- No new error handling required. Optimizations must be purely performance-related with no behavioral changes.

## Acceptance Criteria

1. Given the benchmark script, when run on the 4ree example case, then the optimized build time is at least 30% faster than baseline (2x target is aspirational; 30% is the minimum acceptance threshold).
2. Given the benchmark script, when run on any example case, then total allocations during `Lab.build` are reduced by at least 20% compared to baseline.
3. Given the optimized code, when all existing tests are run, then all tests pass with no regressions.
4. Given the `benchmark/RESULTS.md` file, when reviewed, then it contains before/after numbers for all 4 example cases with wall-clock time and allocation counts.
5. Given the benchmark script, when run with `Threaded` parallel scheme, then the build phase shows no thread-safety issues (build itself is single-threaded, but training uses threads).
6. Given the precomputed bus-entity mappings optimization, when `__add_load_balance!` is called, then it no longer iterates over all entities with filter conditions per bus.

## Implementation Guide

### Suggested Approach

**Phase A: Establish Baseline (Day 1)**

1. Create `benchmark/bench_build.jl`:

```julia
using SDDPlab
using BenchmarkTools
using GLPK

for case in ["1dtoy", "1dsin", "1dsin_ar", "4ree"]
    example_dir = joinpath(@__DIR__, "..", "example", case)
    e = CompositeException()
    study = SDDPlab.read_study(example_dir; e = e)

    result = @benchmark SDDPlab.build($study, GLPK.Optimizer) samples=5 evals=1
    println("$case: $(median(result))")
    println("  allocs: $(allocs(median(result)))")
    println("  memory: $(memory(median(result))) bytes")
end
```

2. Run it and record results in `benchmark/RESULTS.md`.

3. Profile with `Profile.@profile`:

```julia
using Profile
study = SDDPlab.read_study(example_dir; e = CompositeException())
Profile.clear()
@profile SDDPlab.build(study, GLPK.Optimizer)
Profile.print(format=:flat, sortedby=:count)
```

**Phase B: Optimize Entity Lookups (Day 1-2)**

In `__generate_subproblem_builder` (build.jl lines 293-329), precompute entity data before the closure:

```julia
function __generate_subproblem_builder(
    files::Vector{InputModule}, scaling::ScalingConfig
)::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    num_stages = get_number_of_stages(get_graph(scenarios))

    SAA = generate_saa(scenarios, num_stages, scenarios.seed)
    # ... scaling as before ...

    # Precompute entity data for load balance
    hydros_entities = get_hydros_entities(system)
    thermals_entities = get_thermals_entities(system)
    lines_entities = get_lines_entities(system)
    bus_ids = get_ids(get_buses(system))

    # Precompute bus-to-entity index mappings
    hydro_bus_map = _build_bus_index_map(hydros_entities, bus_ids, :bus_id)
    thermal_bus_map = _build_bus_index_map(thermals_entities, bus_ids, :bus_id)
    line_target_map = _build_bus_index_map(lines_entities, bus_ids, :target_bus_id)
    line_source_map = _build_bus_index_map(lines_entities, bus_ids, :source_bus_id)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios, node)
        __add_load_balance!(m, system, scenarios, node, s_gen, bus_ids,
            hydro_bus_map, thermal_bus_map, line_target_map, line_source_map)
        # ... parameterize and objective as before ...
    end
    return fun_sp_build
end
```

Add a helper function:

```julia
function _build_bus_index_map(entities, bus_ids, bus_field::Symbol)
    map = Dict{Integer, Vector{Int}}()
    for (j, entity) in enumerate(entities)
        bid = getfield(entity, bus_field)
        for (n, bus_id) in enumerate(bus_ids)
            if bid == bus_id
                indices = get!(map, n, Int[])
                push!(indices, j)
            end
        end
    end
    return map
end
```

**Phase C: Reduce SAA Allocations (Day 2)**

In `__generate_saa` (naive.jl lines 100-122), preallocate a buffer:

```julia
function __generate_saa(
    rng::AbstractRNG, s::Naive, initial_season::Integer, N::Integer, B::Integer
)::Vector{Vector{Vector{Float64}}}
    size_s = size(s)
    out = [[zeros(size_s[1]) for b in 1:B] for n in 1:N]
    buffer = zeros(size_s[1], 1)  # preallocate for rand!

    for n in 1:N
        m = (n + initial_season - 1)
        season = m - size_s[2] * Int(div(m, size_s[2] + 1e-5))
        D = __build_mvdist(s, season)
        for b in 1:B
            rand!(rng, D, buffer)
            out[n][b] .= @view buffer[:, 1]
        end
    end
    return out
end
```

Note: Verify that `Copulas.rand!` supports in-place generation for `SklarDist`. If not, fall back to `rand(rng, D, 1)` but avoid the `.+=` and use `.=` with a view.

**Phase D: Re-benchmark and Document (Day 2-3)**

Re-run benchmarks, compute speedup ratios, update `benchmark/RESULTS.md`.

### Key Files to Modify

| File                             | Change                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `benchmark/bench_build.jl`       | New file -- benchmark script                                                                           |
| `benchmark/RESULTS.md`           | New file -- baseline and optimized results                                                             |
| `src/Engines/sddp/build.jl`      | Precompute entity lookups; refactor `__add_load_balance!` signature; add `_build_bus_index_map` helper |
| `src/StochasticProcess/naive.jl` | Preallocate buffer in `__generate_saa`; cache `SklarDist` if profitable                                |

### Patterns to Follow

- Use `BenchmarkTools.@benchmark` with `samples=5 evals=1` for build benchmarks (build is expensive, few samples needed).
- Use `Profile.print(format=:flat, sortedby=:count)` for profiling output.
- For precomputed maps, follow Julia convention of returning `Dict` with `get!` for lazy initialization.
- Keep `__add_load_balance!` backward compatible by adding a new method with the precomputed maps rather than modifying the old signature.

### Pitfalls to Avoid

- Do NOT change any mathematical behavior. Optimizations must be purely computational (precomputation, allocation reduction, caching). The subproblem structure, constraints, and objective must be bit-identical.
- Do NOT attempt to parallelize the `fun_sp_build` calls themselves. SDDP.jl's `PolicyGraph` constructor calls `fun_sp_build` sequentially for each node. Parallelizing this would require changes to SDDP.jl itself.
- `Copulas.rand!` may not exist for `SklarDist`. Check before assuming in-place generation is possible. If not available, the allocation optimization in SAA will be limited to removing `.+=` in favor of `.=`.
- The `_build_bus_index_map` helper uses entity field access via `getfield`. Verify that entities have the expected field names (e.g., `bus_id` for hydros/thermals, `target_bus_id`/`source_bus_id` for lines). Check the struct definitions in `src/System/`.
- Do NOT modify the `4ree` example data or any other example data. Benchmarks must use existing examples as-is.

## Testing Requirements

### Unit Tests

1. **Bus index map correctness**: Create a small set of mock entities with known bus_id assignments. Call `_build_bus_index_map` and verify the resulting dict maps each bus index to the correct entity indices.
2. **Precomputed load balance equivalence**: For a small test case, verify that `__add_load_balance!` with precomputed maps produces the same JuMP constraints as the original implementation.

### Integration Tests

1. **All example pipelines pass**: Run all existing pipeline tests in `test/test-main.jl`. All must pass with no changes to expected results.
2. **Benchmark script runs**: Verify `benchmark/bench_build.jl` executes without error and produces output.

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-022 (thread-safe SAA must be in place before profiling under threading makes sense)
- **Blocks**: ticket-024

## Effort Estimate

**Points**: 4
**Confidence**: Medium (actual optimization targets depend on profiling results; the 2x target is aspirational)
