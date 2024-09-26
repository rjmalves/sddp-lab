import SDDPlab: Tasks

using Dates

ITERATION_LIMIT_DICT = convert(Dict{String,Any}, Dict("num_iterations" => 5))

TIME_LIMIT_DICT = convert(Dict{String,Any}, Dict("time_seconds" => 5))

LOWER_BOUND_STABILITY_DICT = convert(
    Dict{String,Any}, Dict("threshold" => 0.05, "num_iterations" => 5)
)

@testset "tasks-stopping-criteria" begin
    @testset "iteration-limit-valid" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        @test typeof(Tasks.IterationLimit(d, e)) === Tasks.IterationLimit
    end

    @testset "time-limit-valid" begin
        d, e = __renew(TIME_LIMIT_DICT)
        @test typeof(Tasks.TimeLimit(d, e)) === Tasks.TimeLimit
    end

    @testset "lower-bound-stability-valid" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        @test typeof(Tasks.LowerBoundStability(d, e)) === Tasks.LowerBoundStability
    end

    @testset "iteration-limit-invalid-num_iterations" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Tasks.IterationLimit(d, e) === nothing
    end

    @testset "time-limit-invalid-time_seconds" begin
        d, e = __renew(TIME_LIMIT_DICT)
        d = __modif_key(d, "time_seconds", 0)
        @test Tasks.TimeLimit(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-threshold" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "threshold", -0.05)
        @test Tasks.LowerBoundStability(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-num_iterations" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Tasks.LowerBoundStability(d, e) === nothing
    end
end