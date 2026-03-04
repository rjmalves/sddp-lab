import SDDPlab: Engines

using Dates

EXPECTATION_DICT = convert(Dict{String,Any}, Dict())
WORSTCASE_DICT = convert(Dict{String,Any}, Dict())
AVAR_DICT = convert(Dict{String,Any}, Dict("alpha" => 0.5))
CVAR_DICT = convert(Dict{String,Any}, Dict("alpha" => 0.2, "lambda" => 0.5))
ENTROPIC_DICT = convert(Dict{String,Any}, Dict("theta" => 0.1))
WASSERSTEIN_RM_DICT = convert(Dict{String,Any}, Dict("alpha" => 0.5))
MODIFIED_CHI_SQUARED_DICT = convert(
    Dict{String,Any}, Dict("radius" => 0.1, "minimum_std" => 0.25)
)
CONVEX_COMBINATION_DICT = convert(
    Dict{String,Any},
    Dict(
        "measures" => [
            Dict{String,Any}(
                "weight" => 0.5,
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
            ),
            Dict{String,Any}(
                "weight" => 0.5,
                "risk_measure" => Dict{String,Any}(
                    "kind" => "AVaR", "params" => Dict{String,Any}("alpha" => 0.1)
                ),
            ),
        ],
    ),
)

@testset "engines-sddp-risk-measure" begin
    @testset "expectation-valid" begin
        d, e = __renew(EXPECTATION_DICT)
        @test typeof(Engines.Expectation(d, e)) === Engines.Expectation
    end

    @testset "worstcase-valid" begin
        d, e = __renew(WORSTCASE_DICT)
        @test typeof(Engines.WorstCase(d, e)) === Engines.WorstCase
    end

    @testset "avar-valid" begin
        d, e = __renew(AVAR_DICT)
        @test typeof(Engines.AVaR(d, e)) === Engines.AVaR
    end

    @testset "avar-invalid-alpha" begin
        d, e = __renew(AVAR_DICT)
        d = __modif_key(d, "alpha", -0.1)
        @test Engines.AVaR(d, e) === nothing
    end

    @testset "cvar-valid" begin
        d, e = __renew(CVAR_DICT)
        @test typeof(Engines.CVaR(d, e)) === Engines.CVaR
    end

    @testset "cvar-invalid-alpha" begin
        d, e = __renew(CVAR_DICT)
        d = __modif_key(d, "alpha", -0.1)
        @test Engines.CVaR(d, e) === nothing
    end

    @testset "cvar-invalid-lambda" begin
        d, e = __renew(CVAR_DICT)
        d = __modif_key(d, "lambda", 1.1)
        @test Engines.CVaR(d, e) === nothing
    end

    @testset "entropic-valid" begin
        d, e = __renew(ENTROPIC_DICT)
        result = Engines.Entropic(d, e)
        @test typeof(result) === Engines.Entropic
        @test result.theta == 0.1
    end

    @testset "entropic-invalid-theta-negative" begin
        d, e = __renew(ENTROPIC_DICT)
        d = __modif_key(d, "theta", -1.0)
        @test Engines.Entropic(d, e) === nothing
        @test length(e) > 0
    end

    @testset "entropic-invalid-theta-zero" begin
        d, e = __renew(ENTROPIC_DICT)
        d = __modif_key(d, "theta", 0.0)
        @test Engines.Entropic(d, e) === nothing
        @test length(e) > 0
    end

    @testset "entropic-missing-theta" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.Entropic(d, e) === nothing
        @test length(e) > 0
    end

    @testset "wasserstein-rm-valid" begin
        d, e = __renew(WASSERSTEIN_RM_DICT)
        result = Engines.WassersteinRM(d, e)
        @test typeof(result) === Engines.WassersteinRM
        @test result.alpha == 0.5
    end

    @testset "wasserstein-rm-invalid-alpha-zero" begin
        d, e = __renew(WASSERSTEIN_RM_DICT)
        d = __modif_key(d, "alpha", 0.0)
        @test Engines.WassersteinRM(d, e) === nothing
        @test length(e) > 0
    end

    @testset "wasserstein-rm-invalid-alpha-one" begin
        d, e = __renew(WASSERSTEIN_RM_DICT)
        d = __modif_key(d, "alpha", 1.0)
        @test Engines.WassersteinRM(d, e) === nothing
        @test length(e) > 0
    end

    @testset "wasserstein-rm-invalid-alpha-above" begin
        d, e = __renew(WASSERSTEIN_RM_DICT)
        d = __modif_key(d, "alpha", 1.5)
        @test Engines.WassersteinRM(d, e) === nothing
        @test length(e) > 0
    end

    @testset "wasserstein-rm-invalid-alpha-negative" begin
        d, e = __renew(WASSERSTEIN_RM_DICT)
        d = __modif_key(d, "alpha", -0.1)
        @test Engines.WassersteinRM(d, e) === nothing
        @test length(e) > 0
    end

    @testset "wasserstein-rm-missing-alpha" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.WassersteinRM(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-valid" begin
        d, e = __renew(MODIFIED_CHI_SQUARED_DICT)
        result = Engines.ModifiedChiSquared(d, e)
        @test typeof(result) === Engines.ModifiedChiSquared
        @test result.radius == 0.1
        @test result.minimum_std == 0.25
    end

    @testset "modified-chi-squared-invalid-radius-negative" begin
        d, e = __renew(MODIFIED_CHI_SQUARED_DICT)
        d = __modif_key(d, "radius", -0.1)
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-invalid-radius-zero" begin
        d, e = __renew(MODIFIED_CHI_SQUARED_DICT)
        d = __modif_key(d, "radius", 0.0)
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-invalid-minimum-std-zero" begin
        d, e = __renew(MODIFIED_CHI_SQUARED_DICT)
        d = __modif_key(d, "minimum_std", 0.0)
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-invalid-minimum-std-one" begin
        d, e = __renew(MODIFIED_CHI_SQUARED_DICT)
        d = __modif_key(d, "minimum_std", 1.0)
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-missing-radius" begin
        d = convert(Dict{String,Any}, Dict("minimum_std" => 0.25))
        e = CompositeException()
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "modified-chi-squared-missing-minimum-std" begin
        d = convert(Dict{String,Any}, Dict("radius" => 0.1))
        e = CompositeException()
        @test Engines.ModifiedChiSquared(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-valid" begin
        d, e = __renew(CONVEX_COMBINATION_DICT)
        result = Engines.ConvexCombination(d, e)
        @test typeof(result) === Engines.ConvexCombination
        @test length(result.measures) == 2
        @test result.measures[1][1] == 0.5
        @test typeof(result.measures[1][2]) === Engines.Expectation
        @test result.measures[2][1] == 0.5
        @test typeof(result.measures[2][2]) === Engines.AVaR
    end

    @testset "convex-combination-invalid-weights-sum" begin
        d = convert(
            Dict{String,Any},
            Dict(
                "measures" => [
                    Dict{String,Any}(
                        "weight" => 0.3,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "Expectation", "params" => Dict{String,Any}()
                        ),
                    ),
                    Dict{String,Any}(
                        "weight" => 0.5,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "AVaR",
                            "params" => Dict{String,Any}("alpha" => 0.1),
                        ),
                    ),
                ],
            ),
        )
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-invalid-inner-measure" begin
        d = convert(
            Dict{String,Any},
            Dict(
                "measures" => [
                    Dict{String,Any}(
                        "weight" => 0.5,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "Expectation", "params" => Dict{String,Any}()
                        ),
                    ),
                    Dict{String,Any}(
                        "weight" => 0.5,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "AVaR",
                            "params" => Dict{String,Any}("alpha" => -0.1),
                        ),
                    ),
                ],
            ),
        )
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-missing-measures" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-empty-measures" begin
        d = convert(Dict{String,Any}, Dict("measures" => []))
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-invalid-weight-zero" begin
        d = convert(
            Dict{String,Any},
            Dict(
                "measures" => [
                    Dict{String,Any}(
                        "weight" => 0.0,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "Expectation", "params" => Dict{String,Any}()
                        ),
                    ),
                    Dict{String,Any}(
                        "weight" => 1.0,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "AVaR",
                            "params" => Dict{String,Any}("alpha" => 0.1),
                        ),
                    ),
                ],
            ),
        )
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-missing-risk-measure-key" begin
        d = convert(
            Dict{String,Any}, Dict("measures" => [Dict{String,Any}("weight" => 1.0)])
        )
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-unrecognized-inner-kind" begin
        d = convert(
            Dict{String,Any},
            Dict(
                "measures" => [
                    Dict{String,Any}(
                        "weight" => 1.0,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "NonExistentRiskMeasure",
                            "params" => Dict{String,Any}(),
                        ),
                    ),
                ],
            ),
        )
        e = CompositeException()
        @test Engines.ConvexCombination(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convex-combination-with-nested-entropic" begin
        d = convert(
            Dict{String,Any},
            Dict(
                "measures" => [
                    Dict{String,Any}(
                        "weight" => 0.7,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "Expectation", "params" => Dict{String,Any}()
                        ),
                    ),
                    Dict{String,Any}(
                        "weight" => 0.3,
                        "risk_measure" => Dict{String,Any}(
                            "kind" => "Entropic",
                            "params" => Dict{String,Any}("theta" => 0.5),
                        ),
                    ),
                ],
            ),
        )
        e = CompositeException()
        result = Engines.ConvexCombination(d, e)
        @test typeof(result) === Engines.ConvexCombination
        @test length(result.measures) == 2
        @test typeof(result.measures[2][2]) === Engines.Entropic
        @test result.measures[2][2].theta == 0.5
    end
end
