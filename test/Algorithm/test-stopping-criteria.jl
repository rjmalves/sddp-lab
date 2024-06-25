import SDDPlab: Algorithm

using Dates

DICT = convert(Dict{String,Any}, Dict("threshold" => 0.05, "num_iterations" => 5))

@testset "algorithm-stopping-criteria" begin
    @testset "lower-bound-stability-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.LowerBoundStability(d, e)) === Algorithm.LowerBoundStability
    end

    @testset "lower-bound-stability-invalid-threshold" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "threshold", -0.05)
        @test Algorithm.LowerBoundStability(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-num_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Algorithm.LowerBoundStability(d, e) === nothing
    end
end