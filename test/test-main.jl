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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.InSampleMC(12, false)
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
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

    @testset "1dtoy-pipeline-autoscaling" begin
        using GLPK
        using SDDP: SDDP
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            num_iters = 50
            convergence = Engines.Convergence(
                1, num_iters, [Engines.IterationLimit(num_iters)]
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                100, Engines.Serial(), Engines.DefaultSampling()
            )

            # Run NoScaling pipeline
            noscale_policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            noscale_engine = Engines.SDDPEngine(noscale_policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
            noscale_study = SDDPlab.Study(original.inputs, noscale_engine)
            noscale_model = SDDPlab.build(noscale_study, GLPK.Optimizer)
            noscale_policy = SDDPlab.train(noscale_study, noscale_model)
            @test noscale_policy !== nothing
            noscale_bound = SDDP.calculate_bound(noscale_model.policy_graph)

            # Run AutoScaling pipeline
            autoscale_policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.AutoScaling(),
            )
            autoscale_engine = Engines.SDDPEngine(autoscale_policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
            autoscale_study = SDDPlab.Study(original.inputs, autoscale_engine)
            autoscale_model = SDDPlab.build(autoscale_study, GLPK.Optimizer)
            autoscale_policy = SDDPlab.train(autoscale_study, autoscale_model)
            @test autoscale_policy !== nothing

            # The scaled model's bound is in scaled cost units.
            # Unscale: multiply by s_cost * s_gen to recover original units.
            s_cost = Engines.get_scaling_factor(
                autoscale_model.scaling, Engines.COST_SCALE
            )
            s_gen = Engines.get_scaling_factor(
                autoscale_model.scaling, :HYDRO_GENERATION
            )
            autoscale_bound_scaled = SDDP.calculate_bound(autoscale_model.policy_graph)
            autoscale_bound = autoscale_bound_scaled * s_cost * s_gen

            # Lower bounds should match within 1% relative tolerance
            @test noscale_bound > 0.0
            @test autoscale_bound > 0.0
            rel_diff = abs(noscale_bound - autoscale_bound) / abs(noscale_bound)
            @test rel_diff < 1e-2

            # Verify full pipeline: simulate and save with AutoScaling
            autoscale_simulation = SDDPlab.simulate(autoscale_study, autoscale_model)
            @test autoscale_simulation !== nothing
            SDDPlab.save_simulation(
                autoscale_study, autoscale_simulation, ".", SDDPlab.ParquetFormat()
            )
        end
    end

    @testset "1dtoy-threaded-type-wiring" begin
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
                Engines.Threaded(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Threaded(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(policy_def, sim_def, Engines.DiagnosticsConfig(false, 1e6, 1e10), Engines.SolverConfig("GLPK", Dict{String,Any}()))
            study = SDDPlab.Study(original.inputs, engine)

            @test study.engine.policy.parallel_scheme isa Engines.Threaded
            @test study.engine.simulation.parallel_scheme isa Engines.Threaded
        end
    end

    @testset "1dtoy-pipeline-solver-from-config" begin
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0
            @test study.engine.solver.solver_name == "GLPK"

            model = SDDPlab.build(study)
            @test model !== nothing
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-asynchronous-type-wiring" begin
        using GLPK
        using Distributed
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
                Engines.Asynchronous(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("GLPK", Dict{String,Any}()),
            )
            study = SDDPlab.Study(original.inputs, engine)

            @test study.engine.policy.parallel_scheme isa Engines.Asynchronous
            @test study.engine.simulation.parallel_scheme isa Engines.Serial
        end
    end

    @testset "1dtoy-pipeline-asynchronous" begin
        using GLPK
        using Distributed
        @suppress begin
            if Distributed.nprocs() == 1
                @info "Skipping Asynchronous integration test: no distributed workers available"
                @test_skip true
            else
                e = CompositeException()
                original = SDDPlab.read_study(example_dir; e = e)
                @test length(e) == 0

                convergence = Engines.Convergence(
                    1, 10, [Engines.IterationLimit(10)]
                )
                policy_def = Engines.SDDPPolicyTaskDefinition(
                    convergence,
                    Engines.Expectation(),
                    Engines.Asynchronous(),
                    Engines.DefaultSampling(),
                    Engines.DefaultDuality(),
                    Engines.DefaultForwardPassStrategy(),
                    Engines.SingleCut(),
                    Engines.NoScaling(),
                )
                sim_def = Engines.SDDPSimulationTaskDefinition(
                    10, Engines.Serial(), Engines.DefaultSampling()
                )
                engine = Engines.SDDPEngine(
                    policy_def,
                    sim_def,
                    Engines.DiagnosticsConfig(false, 1e6, 1e10),
                    Engines.SolverConfig("GLPK", Dict{String,Any}()),
                )
                study = SDDPlab.Study(original.inputs, engine)
                model = SDDPlab.build(study, GLPK.Optimizer)
                policy = SDDPlab.train(study, model)
                @test policy !== nothing
            end
        end
    end
end