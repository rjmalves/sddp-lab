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

    @testset "generate-stopping-rule-statistical" begin
        rule = Engines.generate_stopping_rule(Engines.Statistical(100, 10, 1.96))
        @test typeof(rule) === SDDP.Statistical
    end

    @testset "generate-stopping-rule-simulation-stopping" begin
        rule = Engines.generate_stopping_rule(Engines.SimulationStopping(100, 5))
        @test rule isa SDDP.AbstractStoppingRule
        @test typeof(rule) <: SDDP.SimulationStoppingRule
    end

    @testset "generate-stopping-rule-first-stage-stopping" begin
        rule = Engines.generate_stopping_rule(Engines.FirstStageStopping(1e-3, 5))
        @test typeof(rule) === SDDP.FirstStageStoppingRule
    end

    @testset "generate-stopping-rule-stopping-chain" begin
        chain = Engines.StoppingChain(
            Engines.StoppingCriteria[
                Engines.IterationLimit(100),
                Engines.LowerBoundStability(0.05, 10),
            ],
        )
        rule = Engines.generate_stopping_rule(chain)
        @test typeof(rule) === SDDP.StoppingChain
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

    @testset "generate-risk-measure-entropic" begin
        measure = Engines.generate_risk_measure(Engines.Entropic(0.1))
        @test typeof(measure) === SDDP.Entropic
    end

    @testset "generate-risk-measure-wasserstein-rm" begin
        measure = Engines.generate_risk_measure(Engines.WassersteinRM(0.5))
        @test measure isa SDDP.AbstractRiskMeasure
        @test typeof(measure) <: SDDP.Wasserstein
    end

    @testset "generate-risk-measure-modified-chi-squared" begin
        measure = Engines.generate_risk_measure(Engines.ModifiedChiSquared(0.1, 0.25))
        @test typeof(measure) === SDDP.ModifiedChiSquared
    end

    @testset "generate-risk-measure-convex-combination" begin
        inner_measures = Tuple{Real,Engines.RiskMeasure}[
            (0.5, Engines.Expectation()),
            (0.5, Engines.AVaR(0.1)),
        ]
        measure = Engines.generate_risk_measure(Engines.ConvexCombination(inner_measures))
        @test measure isa SDDP.AbstractRiskMeasure
        @test typeof(measure) <: SDDP.ConvexCombination
    end

    @testset "generate-cut-type-single" begin
        ct = Engines.generate_cut_type(Engines.SingleCut())
        @test ct === SDDP.SINGLE_CUT
        @test typeof(ct) === SDDP.CutType
    end

    @testset "generate-cut-type-multi" begin
        ct = Engines.generate_cut_type(Engines.MultiCut())
        @test ct === SDDP.MULTI_CUT
        @test typeof(ct) === SDDP.CutType
    end

    @testset "get-policy-definition" begin
        convergence = Engines.Convergence(10, 128, [Engines.IterationLimit(128)])
        risk = Engines.Expectation()
        parallel = Engines.Serial()
        sampling = Engines.DefaultSampling()
        duality = Engines.DefaultDuality()
        forward_pass = Engines.DefaultForwardPassStrategy()
        cut_type = Engines.SingleCut()
        scaling = Engines.NoScaling()
        policy = Engines.SDDPPolicyTaskDefinition(
            convergence, risk, parallel, sampling, duality, forward_pass, cut_type, scaling
        )
        simulation = Engines.SDDPSimulationTaskDefinition(100, parallel, sampling)
        engine = Engines.SDDPEngine(policy, simulation, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))

        result = Engines.get_policy_definition(engine)
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test result === policy
    end

    @testset "get-simulation-definition" begin
        convergence = Engines.Convergence(10, 128, [Engines.IterationLimit(128)])
        risk = Engines.Expectation()
        parallel = Engines.Serial()
        sampling = Engines.DefaultSampling()
        duality = Engines.DefaultDuality()
        forward_pass = Engines.DefaultForwardPassStrategy()
        cut_type = Engines.SingleCut()
        scaling = Engines.NoScaling()
        policy = Engines.SDDPPolicyTaskDefinition(
            convergence, risk, parallel, sampling, duality, forward_pass, cut_type, scaling
        )
        simulation = Engines.SDDPSimulationTaskDefinition(100, parallel, sampling)
        engine = Engines.SDDPEngine(policy, simulation, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))

        result = Engines.get_simulation_definition(engine)
        @test typeof(result) === Engines.SDDPSimulationTaskDefinition
        @test result === simulation
    end

    @testset "get-stopping-criteria" begin
        stopping = Engines.IterationLimit(128)
        convergence = Engines.Convergence(10, 128, [stopping])

        result = Engines.get_stopping_criteria(convergence)
        @test result isa Vector{Engines.StoppingCriteria}
        @test length(result) == 1
        @test result[1] === stopping
    end

    @testset "get-stopping-criteria-multiple" begin
        s1 = Engines.IterationLimit(128)
        s2 = Engines.LowerBoundStability(0.05, 5)
        convergence = Engines.Convergence(10, 128, Engines.StoppingCriteria[s1, s2])

        result = Engines.get_stopping_criteria(convergence)
        @test result isa Vector{Engines.StoppingCriteria}
        @test length(result) == 2
        @test result[1] === s1
        @test result[2] === s2
    end
end
