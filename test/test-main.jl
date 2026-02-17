using SDDPlab: SDDPlab
import SDDPlab: Engines
using Suppressor

@testset "main" begin
    @testset "main_success" begin
        e = CompositeException()
        using GLPK
        @suppress begin
            study = SDDPlab.read_study(example_dir; e = e)
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            SDDPlab.save_policy(study, policy, ".", SDDPlab.ParquetFormat())
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.load_policy(model, ".", SDDPlab.ParquetFormat())
            simulation = SDDPlab.simulate(study, model)
            SDDPlab.save_simulation(study, simulation, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end

    @testset "1dsin-pipeline" begin
        using GLPK
        example_1dsin = joinpath(@__DIR__, "..", "example", "1dsin")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_1dsin; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dsin_ar-pipeline" begin
        using GLPK
        example_1dsin_ar = joinpath(@__DIR__, "..", "example", "1dsin_ar")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_1dsin_ar; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "4ree-pipeline" begin
        using GLPK
        example_4ree = joinpath(@__DIR__, "..", "example", "4ree")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_4ree; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-statistical-stopping" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.Statistical(10, 1, 1.96), Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end

    @testset "1dtoy-pipeline-multiple-stopping-criteria" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1,
                20,
                [Engines.IterationLimit(10), Engines.LowerBoundStability(0.05, 5)],
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end

    @testset "1dtoy-pipeline-explicit-insamplemc-simulation" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.InSampleMC(12, false),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.InSampleMC(12, false)
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-strengthened-conic-duality" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.StrengthenedConicDualityHandler(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-revisiting-forward-pass" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.RevisitingForwardPassStrategy(3),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-risk-adjusted-forward-pass" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.RiskAdjustedForwardPassStrategy(),
                Engines.SingleCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-multi-cut" begin
        using GLPK
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 10, [Engines.IterationLimit(10)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.MultiCut(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def)
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            SDDPlab.save_policy(study, policy, ".", SDDPlab.ParquetFormat())
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.load_policy(model, ".", SDDPlab.ParquetFormat())
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end
end