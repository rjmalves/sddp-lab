import SDDPlab: Engines

using Dates

ITERATION_LIMIT_DICT = convert(Dict{String,Any}, Dict("num_iterations" => 5))

TIME_LIMIT_DICT = convert(Dict{String,Any}, Dict("time_seconds" => 5))

LOWER_BOUND_STABILITY_DICT = convert(
    Dict{String,Any}, Dict("threshold" => 0.05, "num_iterations" => 5)
)

@testset "engines-sddp-stopping-criteria" begin
    @testset "iteration-limit-valid" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        @test typeof(Engines.IterationLimit(d, e)) === Engines.IterationLimit
    end

    @testset "time-limit-valid" begin
        d, e = __renew(TIME_LIMIT_DICT)
        @test typeof(Engines.TimeLimit(d, e)) === Engines.TimeLimit
    end

    @testset "lower-bound-stability-valid" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        @test typeof(Engines.LowerBoundStability(d, e)) === Engines.LowerBoundStability
    end

    @testset "iteration-limit-invalid-num_iterations" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Engines.IterationLimit(d, e) === nothing
    end

    @testset "time-limit-invalid-time_seconds" begin
        d, e = __renew(TIME_LIMIT_DICT)
        d = __modif_key(d, "time_seconds", 0)
        @test Engines.TimeLimit(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-threshold" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "threshold", -0.05)
        @test Engines.LowerBoundStability(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-num_iterations" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Engines.LowerBoundStability(d, e) === nothing
    end
end