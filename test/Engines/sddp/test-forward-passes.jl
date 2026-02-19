import SDDPlab: Engines

using SDDP: SDDP

DEFAULT_FORWARD_PASS_DICT = convert(Dict{String,Any}, Dict())
REVISITING_FORWARD_PASS_DICT = convert(Dict{String,Any}, Dict("period" => 5))
RISK_ADJUSTED_FORWARD_PASS_DICT = convert(Dict{String,Any}, Dict())
REGULARIZED_FORWARD_PASS_DICT = convert(Dict{String,Any}, Dict("rho" => 0.1))

@testset "engines-sddp-forward-passes" begin
    @testset "default-forward-pass-valid" begin
        d, e = __renew(DEFAULT_FORWARD_PASS_DICT)
        result = Engines.DefaultForwardPassStrategy(d, e)
        @test typeof(result) === Engines.DefaultForwardPassStrategy
        @test length(e) == 0
    end

    @testset "revisiting-forward-pass-valid" begin
        d, e = __renew(REVISITING_FORWARD_PASS_DICT)
        result = Engines.RevisitingForwardPassStrategy(d, e)
        @test typeof(result) === Engines.RevisitingForwardPassStrategy
        @test result.period == 5
        @test length(e) == 0
    end

    @testset "revisiting-forward-pass-invalid-period-zero" begin
        d, e = __renew(REVISITING_FORWARD_PASS_DICT)
        d = __modif_key(d, "period", 0)
        @test Engines.RevisitingForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "revisiting-forward-pass-invalid-period-negative" begin
        d, e = __renew(REVISITING_FORWARD_PASS_DICT)
        d = __modif_key(d, "period", -3)
        @test Engines.RevisitingForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "revisiting-forward-pass-missing-period" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.RevisitingForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "risk-adjusted-forward-pass-valid" begin
        d, e = __renew(RISK_ADJUSTED_FORWARD_PASS_DICT)
        result = Engines.RiskAdjustedForwardPassStrategy(d, e)
        @test typeof(result) === Engines.RiskAdjustedForwardPassStrategy
        @test length(e) == 0
    end

    @testset "regularized-forward-pass-valid" begin
        d, e = __renew(REGULARIZED_FORWARD_PASS_DICT)
        result = Engines.RegularizedForwardPassStrategy(d, e)
        @test typeof(result) === Engines.RegularizedForwardPassStrategy
        @test result.rho == 0.1
        @test length(e) == 0
    end

    @testset "regularized-forward-pass-invalid-rho-zero" begin
        d, e = __renew(REGULARIZED_FORWARD_PASS_DICT)
        d = __modif_key(d, "rho", 0)
        @test Engines.RegularizedForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "regularized-forward-pass-invalid-rho-negative" begin
        d, e = __renew(REGULARIZED_FORWARD_PASS_DICT)
        d = __modif_key(d, "rho", -0.5)
        @test Engines.RegularizedForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "regularized-forward-pass-missing-rho" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.RegularizedForwardPassStrategy(d, e) === nothing
        @test length(e) > 0
    end

    @testset "generate-forward-pass-default" begin
        fp = Engines.generate_forward_pass(Engines.DefaultForwardPassStrategy())
        @test fp isa SDDP.AbstractForwardPass
        @test typeof(fp) === SDDP.DefaultForwardPass
    end

    @testset "generate-forward-pass-revisiting" begin
        fp = Engines.generate_forward_pass(Engines.RevisitingForwardPassStrategy(5))
        @test fp isa SDDP.AbstractForwardPass
        @test typeof(fp) === SDDP.RevisitingForwardPass
        @test fp.period == 5
    end

    @testset "generate-forward-pass-risk-adjusted" begin
        fp = Engines.generate_forward_pass(Engines.RiskAdjustedForwardPassStrategy())
        @test fp isa SDDP.AbstractForwardPass
        @test typeof(fp) <: SDDP.RiskAdjustedForwardPass
    end

    @testset "generate-forward-pass-regularized" begin
        fp = Engines.generate_forward_pass(Engines.RegularizedForwardPassStrategy(0.1))
        @test fp isa SDDP.AbstractForwardPass
        @test typeof(fp) <: SDDP.RegularizedForwardPass
    end

    @testset "forward-pass-kind-factory-default" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "forward_pass" => Dict{String,Any}(
                "kind" => "DefaultForwardPassStrategy", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.forward_pass) === Engines.DefaultForwardPassStrategy
    end

    @testset "forward-pass-kind-factory-revisiting" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "forward_pass" => Dict{String,Any}(
                "kind" => "RevisitingForwardPassStrategy",
                "params" => Dict{String,Any}("period" => 10),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.forward_pass) === Engines.RevisitingForwardPassStrategy
        @test result.forward_pass.period == 10
    end

    @testset "forward-pass-kind-factory-risk-adjusted" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "forward_pass" => Dict{String,Any}(
                "kind" => "RiskAdjustedForwardPassStrategy",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.forward_pass) === Engines.RiskAdjustedForwardPassStrategy
    end

    @testset "forward-pass-kind-factory-regularized" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "forward_pass" => Dict{String,Any}(
                "kind" => "RegularizedForwardPassStrategy",
                "params" => Dict{String,Any}("rho" => 0.25),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.forward_pass) === Engines.RegularizedForwardPassStrategy
        @test result.forward_pass.rho == 0.25
    end

    @testset "forward-pass-backward-compat-policy" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.forward_pass) === Engines.DefaultForwardPassStrategy
    end

    @testset "forward-pass-invalid-kind" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "forward_pass" => Dict{String,Any}(
                "kind" => "NonExistentForwardPass", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result === nothing
        @test length(e) > 0
    end
end
