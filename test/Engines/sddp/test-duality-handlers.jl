import SDDPlab: Engines

using SDDP: SDDP

DEFAULT_DUALITY_DICT = convert(Dict{String,Any}, Dict())
CONTINUOUS_CONIC_DICT = convert(Dict{String,Any}, Dict())
STRENGTHENED_CONIC_DICT = convert(Dict{String,Any}, Dict())
LAGRANGIAN_DICT = convert(Dict{String,Any}, Dict())

BANDIT_DICT = Dict{String,Any}(
    "handlers" => [
        Dict{String,Any}(
            "kind" => "ContinuousConicDualityHandler", "params" => Dict{String,Any}()
        ),
        Dict{String,Any}(
            "kind" => "StrengthenedConicDualityHandler", "params" => Dict{String,Any}()
        ),
    ],
)

@testset "engines-sddp-duality-handlers" begin
    @testset "default-duality-valid" begin
        d, e = __renew(DEFAULT_DUALITY_DICT)
        result = Engines.DefaultDuality(d, e)
        @test typeof(result) === Engines.DefaultDuality
        @test length(e) == 0
    end

    @testset "continuous-conic-duality-valid" begin
        d, e = __renew(CONTINUOUS_CONIC_DICT)
        result = Engines.ContinuousConicDualityHandler(d, e)
        @test typeof(result) === Engines.ContinuousConicDualityHandler
        @test length(e) == 0
    end

    @testset "strengthened-conic-duality-valid" begin
        d, e = __renew(STRENGTHENED_CONIC_DICT)
        result = Engines.StrengthenedConicDualityHandler(d, e)
        @test typeof(result) === Engines.StrengthenedConicDualityHandler
        @test length(e) == 0
    end

    @testset "lagrangian-duality-valid" begin
        d, e = __renew(LAGRANGIAN_DICT)
        result = Engines.LagrangianDualityHandler(d, e)
        @test typeof(result) === Engines.LagrangianDualityHandler
        @test length(e) == 0
    end

    @testset "bandit-duality-valid" begin
        d = deepcopy(BANDIT_DICT)
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test typeof(result) === Engines.BanditDualityHandler
        @test length(result.handlers) == 2
        @test typeof(result.handlers[1]) === Engines.ContinuousConicDualityHandler
        @test typeof(result.handlers[2]) === Engines.StrengthenedConicDualityHandler
        @test length(e) == 0
    end

    @testset "bandit-duality-insufficient-handlers" begin
        d = Dict{String,Any}(
            "handlers" => [
                Dict{String,Any}(
                    "kind" => "ContinuousConicDualityHandler",
                    "params" => Dict{String,Any}(),
                ),
            ],
        )
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "bandit-duality-empty-handlers" begin
        d = Dict{String,Any}("handlers" => Any[])
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "bandit-duality-missing-handlers-key" begin
        d = Dict{String,Any}()
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "bandit-duality-invalid-inner-kind" begin
        d = Dict{String,Any}(
            "handlers" => [
                Dict{String,Any}(
                    "kind" => "ContinuousConicDualityHandler",
                    "params" => Dict{String,Any}(),
                ),
                Dict{String,Any}(
                    "kind" => "NonExistentHandler", "params" => Dict{String,Any}()
                ),
            ],
        )
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "bandit-duality-inner-not-duality-handler" begin
        d = Dict{String,Any}(
            "handlers" => [
                Dict{String,Any}(
                    "kind" => "ContinuousConicDualityHandler",
                    "params" => Dict{String,Any}(),
                ),
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            ],
        )
        e = CompositeException()
        result = Engines.BanditDualityHandler(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "generate-duality-handler-continuous-conic" begin
        handler = Engines.generate_duality_handler(Engines.ContinuousConicDualityHandler())
        @test handler isa SDDP.AbstractDualityHandler
        @test typeof(handler) <: SDDP.ContinuousConicDuality
    end

    @testset "generate-duality-handler-strengthened-conic" begin
        handler = Engines.generate_duality_handler(
            Engines.StrengthenedConicDualityHandler()
        )
        @test handler isa SDDP.AbstractDualityHandler
        @test typeof(handler) <: SDDP.StrengthenedConicDuality
    end

    @testset "generate-duality-handler-lagrangian" begin
        handler = Engines.generate_duality_handler(Engines.LagrangianDualityHandler())
        @test handler isa SDDP.AbstractDualityHandler
        @test typeof(handler) <: SDDP.LagrangianDuality
    end

    @testset "generate-duality-handler-bandit" begin
        bandit = Engines.BanditDualityHandler(
            Engines.DualityHandler[
                Engines.ContinuousConicDualityHandler(),
                Engines.StrengthenedConicDualityHandler(),
            ],
        )
        handler = Engines.generate_duality_handler(bandit)
        @test handler isa SDDP.AbstractDualityHandler
        @test typeof(handler) <: SDDP.BanditDuality
    end

    @testset "duality-handler-kind-factory-continuous-conic" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "ContinuousConicDualityHandler",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.duality_handler) === Engines.ContinuousConicDualityHandler
    end

    @testset "duality-handler-kind-factory-strengthened-conic" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "StrengthenedConicDualityHandler",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.duality_handler) === Engines.StrengthenedConicDualityHandler
    end

    @testset "duality-handler-kind-factory-lagrangian" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "LagrangianDualityHandler", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.duality_handler) === Engines.LagrangianDualityHandler
    end

    @testset "duality-handler-kind-factory-bandit" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "BanditDualityHandler",
                "params" => Dict{String,Any}(
                    "handlers" => [
                        Dict{String,Any}(
                            "kind" => "ContinuousConicDualityHandler",
                            "params" => Dict{String,Any}(),
                        ),
                        Dict{String,Any}(
                            "kind" => "StrengthenedConicDualityHandler",
                            "params" => Dict{String,Any}(),
                        ),
                    ],
                ),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.duality_handler) === Engines.BanditDualityHandler
        @test length(result.duality_handler.handlers) == 2
    end

    @testset "duality-handler-kind-factory-default" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "DefaultDuality", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.duality_handler) === Engines.DefaultDuality
    end

    @testset "duality-handler-backward-compat-policy" begin
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
        @test typeof(result.duality_handler) === Engines.DefaultDuality
    end

    @testset "duality-handler-invalid-kind" begin
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
            "duality_handler" => Dict{String,Any}(
                "kind" => "NonExistentDuality", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result === nothing
        @test length(e) > 0
    end
end
