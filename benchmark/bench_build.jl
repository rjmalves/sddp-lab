"""
Benchmark script for SDDPlab.build hot paths.

Measures wall-clock time and allocations for Lab.build on all 4 example cases.
Run from the repository root:

    julia --project benchmark/bench_build.jl

Results are printed to stdout. Capture them and compare before/after optimizations.
"""

using SDDPlab
using BenchmarkTools
using GLPK
using Dates
using Printf

# Redirect all logging output to devnull during benchmarking so it does not pollute results
import Logging: NullLogger, with_logger

function quiet_build(study)
    return with_logger(NullLogger()) do
        SDDPlab.build(study, GLPK.Optimizer)
    end
end

function quiet_read(path)
    e = CompositeException()
    study = with_logger(NullLogger()) do
        SDDPlab.read_study(path; e = e)
    end
    return study, e
end

# Warm up the JIT on the smallest case before benchmarking
function warmup()
    example_dir = joinpath(@__DIR__, "..", "example", "1dtoy")
    study, _ = quiet_read(example_dir)
    quiet_build(study)
    return nothing
end

function run_benchmarks()
    println("=" ^ 60)
    println("SDDPlab.build benchmark")
    println("Julia version: ", VERSION)
    println("Date: ", Dates.now())
    println("=" ^ 60)
    println()

    warmup()
    println("JIT warm-up complete.")
    println()

    cases = ["1dtoy", "1dsin", "1dsin_ar", "4ree"]

    for case in cases
        example_dir = joinpath(@__DIR__, "..", "example", case)
        study, e = quiet_read(example_dir)
        if length(e) > 0
            @warn "Errors reading study for $case" errors=e
            continue
        end

        # Run benchmark: samples=5, evals=1 because build is expensive
        result = @benchmark(quiet_build($study), samples = 5, evals = 1)

        med = median(result)
        println("Case: $case")
        @printf "  Median time:   %10.3f ms\n" med.time / 1e6
        @printf "  Allocations:   %10d\n" med.allocs
        @printf "  Memory:        %10.3f MiB\n" med.memory / (1024^2)
        @printf "  Min time:      %10.3f ms\n" minimum(result).time / 1e6
        @printf "  Max time:      %10.3f ms\n" maximum(result).time / 1e6
        println()
    end

    println("=" ^ 60)
    println("Benchmark complete.")
end

run_benchmarks()
