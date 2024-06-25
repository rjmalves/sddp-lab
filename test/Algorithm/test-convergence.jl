import SDDPlab: Algorithm

using Dates

DICT::Dict{String,Any} = Dict(
    "min_iterations" => 10,
    "max_iterations" => 100,
    "stopping_criteria" => Dict(
        "kind" => "LowerBoundStability",
        "params" => Dict("threshold" => 0.05, "num_iterations" => 5),
    ),
)

@testset "algorithm-convergence" begin
    @testset "convergence-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.Convergence(d, e)) === Algorithm.Convergence
    end

    @testset "convergence-invalid-min_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        @test Algorithm.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-max_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        d = __modif_key(d, "max_iterations", -5)
        @test Algorithm.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_iterations", 1)
        @test Algorithm.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-stopping_criteria" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stopping_criteria",
            Dict(
                "kind" => "LowerBoundStability",
                "params" => Dict("threshold" => -0.05, "num_iterations" => 5),
            ),
        )
        @test Algorithm.Convergence(d, e) === nothing
    end
end