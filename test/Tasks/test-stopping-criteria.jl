import SDDPlab: Tasks

using Dates

DICT = convert(Dict{String,Any}, Dict("threshold" => 0.05, "num_iterations" => 5))

@testset "tasks-stopping-criteria" begin
    @testset "lower-bound-stability-valid" begin
        d, e = __renew(DICT)
        @test typeof(Tasks.LowerBoundStability(d, e)) === Tasks.LowerBoundStability
    end

    @testset "lower-bound-stability-invalid-threshold" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "threshold", -0.05)
        @test Tasks.LowerBoundStability(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-num_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Tasks.LowerBoundStability(d, e) === nothing
    end
end