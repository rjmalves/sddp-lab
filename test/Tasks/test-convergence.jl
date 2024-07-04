import SDDPlab: Tasks

using Dates

DICT = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 100,
    "stopping_criteria" => Dict(
        "kind" => "LowerBoundStability",
        "params" => Dict("threshold" => 0.05, "num_iterations" => 5),
    ),
)

@testset "tasks-convergence" begin
    @testset "convergence-valid" begin
        d, e = __renew(DICT)
        @test typeof(Tasks.Convergence(d, e)) === Tasks.Convergence
    end

    @testset "convergence-invalid-min_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        @test Tasks.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-max_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        d = __modif_key(d, "max_iterations", -5)
        @test Tasks.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_iterations", 1)
        @test Tasks.Convergence(d, e) === nothing
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
        @test Tasks.Convergence(d, e) === nothing
    end
end