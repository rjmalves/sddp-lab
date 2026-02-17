import SDDPlab: Engines

using Dates

DICT = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 100,
    "stopping_criteria" => Dict(
        "kind" => "LowerBoundStability",
        "params" => Dict("threshold" => 0.05, "num_iterations" => 5),
    ),
)

@testset "engines-sddp-convergence" begin
    @testset "convergence-valid" begin
        d, e = __renew(DICT)
        @test typeof(Engines.Convergence(d, e)) === Engines.Convergence
    end

    @testset "convergence-invalid-min_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-max_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        d = __modif_key(d, "max_iterations", -5)
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_iterations", 1)
        @test Engines.Convergence(d, e) === nothing
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
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-missing-stopping-criteria" begin
        d, e = __renew(DICT)
        delete!(d, "stopping_criteria")
        @test Engines.Convergence(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convergence-unrecognized-stopping-criteria-kind" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stopping_criteria",
            Dict("kind" => "UnknownCriteria", "params" => Dict{String,Any}()),
        )
        @test Engines.Convergence(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convergence-equal-min-max-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", 50)
        d = __modif_key(d, "max_iterations", 50)
        conv = Engines.Convergence(d, e)
        @test typeof(conv) === Engines.Convergence
    end
end