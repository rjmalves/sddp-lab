# SDDPlab Build Benchmark Results

## Environment

- Julia: 1.12.5
- Platform: Linux x86_64
- Benchmark tool: `BenchmarkTools.jl` (`@benchmark`, `samples=5, evals=1`)
- Date of baseline: 2026-02-18
- Date of optimized: 2026-02-18

## Methodology

All benchmarks use `SDDPlab.build(study, GLPK.Optimizer)` on the example cases. A JIT
warm-up pass over `1dtoy` is performed before timing begins. The `NullLogger()` suppresses
all `@info` output so logging overhead is excluded from measurements. Median time and
allocation count from 5 samples are reported.

## Baseline Results (before optimization)

| Case     | Median Time (ms) | Allocations | Memory (MiB) |
| -------- | ---------------- | ----------- | ------------ |
| 1dtoy    | 0.257            | 2,980       | 0.152        |
| 1dsin    | 4.239            | 122,687     | 6.993        |
| 1dsin_ar | 4.217            | 127,188     | 7.203        |
| 4ree     | 2.527            | 68,020      | 3.912        |

## Optimized Results (after optimization)

| Case     | Median Time (ms) | Allocations | Memory (MiB) |
| -------- | ---------------- | ----------- | ------------ |
| 1dtoy    | 0.194            | 2,740       | 0.144        |
| 1dsin    | 3.873            | 121,336     | 6.948        |
| 1dsin_ar | 3.838            | 125,837     | 7.158        |
| 4ree     | 2.269            | 67,546      | 3.895        |

## Speedup Summary

| Case     | Time Speedup | Alloc Reduction | Memory Reduction |
| -------- | ------------ | --------------- | ---------------- |
| 1dtoy    | 24.5%        | 8.1%            | 5.3%             |
| 1dsin    | 8.6%         | 1.1%            | 0.6%             |
| 1dsin_ar | 9.0%         | 1.1%            | 0.6%             |
| 4ree     | 10.2%        | 0.7%            | 0.4%             |

## Optimizations Applied

### 1. Precomputed entity lookup maps in `__generate_subproblem_builder`

**File**: `src/Engines/sddp/build.jl`

**What changed**: The `__add_load_balance!` function previously extracted entity vectors
and bus ids from `SystemData` on every subproblem node call. It then iterated over ALL
entities with filter conditions per bus (O(num_entities) per bus per node). With 126
thermals and 5 buses in the 4ree case, this was 630 comparisons per node call repeated
over all 11 non-root nodes.

**Optimization**:

- Added `_build_bus_index_map` helper that precomputes a `Dict{Int, Vector{Int}}` mapping
  each bus position to the entity indices assigned to it
- Added new `__add_load_balance!` overload that accepts precomputed maps and uses
  `get(map, n, Int[])` for O(1) direct lookup instead of filtered generator comprehensions
- `__generate_subproblem_builder` now precomputes 4 maps (hydro by bus, thermal by bus,
  line by target bus, line by source bus) once before creating the closure
- `get_ids(get_buses(system))` is computed once instead of per node (avoids allocating a
  new `Vector{Integer}` per node call)
- The original `__add_load_balance!(m, files, node, load_scale)` signature is preserved
  unchanged for backward compatibility

### 2. In-place buffer for SAA sampling in `__generate_saa`

**File**: `src/StochasticProcess/naive.jl`

**What changed**: The original `__generate_saa` called `rand(rng, D, 1)` inside the inner
loop, allocating a new `Matrix{Float64}(n_vars, 1)` for each (stage, branching) sample.
It then used `.+=` to accumulate into `out[n][b]` which was initialized to zeros.

**Optimization**:

- Preallocated a single `buffer = zeros(size_s[1], 1)` matrix before the loop
- Use `rand!(rng, D, buffer)` for in-place random generation (avoids one `Matrix{Float64}`
  allocation per sample; verified that `Copulas.SklarDist` supports in-place `rand!`)
- Use `.= @view buffer[:, 1]` (assignment from view) instead of `.+= sim` (unnecessary
  accumulation since `out[n][b]` is initialised to zeros)

**Impact in isolation** (micro-benchmark on 1-hydro, 24-stage, 10-branching case):

- Allocations: 1,010 -> 532 (47% reduction in SAA generation only)
- Time: 0.010 ms -> 0.008 ms (20% speedup in SAA generation only)

The impact on total build time is small because SAA generation is a minor fraction of total
build cost for the example cases measured (dominated by JuMP model construction).

## Analysis

The majority of build time and allocations is consumed by JuMP's internal model construction
machinery: `@variable`, `@constraint`, `@expression`, and `@stageobjective` macros. These
macros allocate containers, ordered dicts, and affine expression objects for each model
element. With 126 thermal variables (each requiring bounds, expression, and objective
terms) built per subproblem node, JuMP's construction overhead dominates.

The profiler confirms that most samples are spent inside JuMP's `container.jl`,
`@variable.jl`, and `@expression.jl` (from the `Containers` module), not in any
SDDPlab-specific code. These internal JuMP allocations are not reducible without
modifying JuMP.jl itself or restructuring the model to share constraints across nodes
(which would require SDDP.jl architecture changes).

### What the optimizations achieve

The implemented optimizations eliminate the avoidable work:

- Entity extraction calls (`get_system`, `get_scenarios`, `get_ids`) that were repeated
  per node are now done once
- The O(num_entities \* num_buses) filter in load balance is replaced with O(num_buses)
  dict lookup
- One `Matrix{Float64}` heap allocation per SAA sample is eliminated via in-place rand!

The 8-25% speedup on 1dtoy (the simplest case where JuMP overhead is proportionally
smaller relative to our code) reflects the actual algorithmic improvement. For larger
cases (4ree, 1dsin), JuMP dominates and our improvements are proportionally smaller.

### Path to larger speedups

To achieve 2x or greater speedups on the 4ree case, the following approaches would be
needed (outside the scope of this ticket):

1. **Lazy constraint sharing**: Build element constraints once per element type and reuse
   across nodes using JuMP's parametric constraint approach
2. **Direct MOI API usage**: Bypass JuMP's `@variable`/`@constraint` macros and use
   `MOI.add_variable` / `MOI.add_constraint` directly to avoid JuMP container overhead
3. **Model templating**: Build a template subproblem structure once and clone it per node
   using MOI's `copy_to` semantics
