import SDDPlab: Engines
using SDDP: SDDP

@testset "engines-sddp-mappings" begin
    @testset "generate-stopping-rule-iteration-limit" begin
        rule = Engines.generate_stopping_rule(Engines.IterationLimit(128))
        @test typeof(rule) === SDDP.IterationLimit
    end

    @testset "generate-stopping-rule-time-limit" begin
        rule = Engines.generate_stopping_rule(Engines.TimeLimit(60))
        @test typeof(rule) === SDDP.TimeLimit
    end

    @testset "generate-stopping-rule-lower-bound-stability" begin
        rule = Engines.generate_stopping_rule(Engines.LowerBoundStability(0.05, 5))
        @test typeof(rule) === SDDP.BoundStalling
    end

    @testset "generate-parallel-scheme-serial" begin
        scheme = Engines.generate_parallel_scheme(Engines.Serial())
        @test typeof(scheme) === SDDP.Serial
    end

    @testset "generate-risk-measure-expectation" begin
        measure = Engines.generate_risk_measure(Engines.Expectation())
        @test typeof(measure) === SDDP.Expectation
    end

    @testset "generate-risk-measure-worstcase" begin
        measure = Engines.generate_risk_measure(Engines.WorstCase())
        @test typeof(measure) === SDDP.WorstCase
    end

    @testset "generate-risk-measure-avar" begin
        measure = Engines.generate_risk_measure(Engines.AVaR(0.5))
        @test typeof(measure) === SDDP.AVaR
    end

    @testset "generate-risk-measure-cvar" begin
        measure = Engines.generate_risk_measure(Engines.CVaR(0.2, 0.9))
        @test measure isa SDDP.AbstractRiskMeasure
        @test typeof(measure) <: SDDP.ConvexCombination
    end

    @testset "get-policy-definition" begin
        convergence = Engines.Convergence(10, 128, Engines.IterationLimit(128))
        risk = Engines.Expectation()
        parallel = Engines.Serial()
        policy = Engines.SDDPPolicyTaskDefinition(convergence, risk, parallel)
        simulation = Engines.SDDPSimulationTaskDefinition(100, parallel)
        engine = Engines.SDDPEngine(policy, simulation)

        result = Engines.get_policy_definition(engine)
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test result === policy
    end

    @testset "get-simulation-definition" begin
        convergence = Engines.Convergence(10, 128, Engines.IterationLimit(128))
        risk = Engines.Expectation()
        parallel = Engines.Serial()
        policy = Engines.SDDPPolicyTaskDefinition(convergence, risk, parallel)
        simulation = Engines.SDDPSimulationTaskDefinition(100, parallel)
        engine = Engines.SDDPEngine(policy, simulation)

        result = Engines.get_simulation_definition(engine)
        @test typeof(result) === Engines.SDDPSimulationTaskDefinition
        @test result === simulation
    end

    @testset "get-stopping-criteria" begin
        stopping = Engines.IterationLimit(128)
        convergence = Engines.Convergence(10, 128, stopping)

        result = Engines.get_stopping_criteria(convergence)
        @test result isa Engines.StoppingCriteria
        @test result === stopping
    end
end
