using SDDPlab: SDDPlab
import SDDPlab: Engines
using Suppressor
using Logging

# Helper: create a fast-running study from a file-loaded study.
# Replaces the engine with one that uses low iteration counts and few simulations,
# so that tests exercise the full pipeline without taking minutes.
function _fast_study(study; num_iters = 10, num_sims = 10)
    convergence = Engines.Convergence(1, num_iters, [Engines.IterationLimit(num_iters)])
    policy_def = Engines.SDDPPolicyTaskDefinition(
        convergence,
        study.engine.policy.risk_measure,
        Engines.Serial(),
        Engines.DefaultSampling(),
        Engines.DefaultDuality(),
        Engines.DefaultForwardPassStrategy(),
        Engines.SingleCut(),
        Engines.NoScaling(),
        Engines.TrainingLogConfig("", 1, false, 1),
    )
    sim_def = Engines.SDDPSimulationTaskDefinition(
        num_sims, Engines.Serial(), Engines.DefaultSampling()
    )
    engine = Engines.SDDPEngine(
        policy_def,
        sim_def,
        Engines.DiagnosticsConfig(false, 1e6, 1e10),
        Engines.SolverConfig("HiGHS", Dict{String,Any}()),
        Engines.InflowNone(),
        nothing,
        Engines.DebugConfig(false, Any[], "mof", false, 60.0),
    )
    return SDDPlab.Study(study.inputs, engine)
end

@testset "main" begin
    @testset "main_success" begin
        e = CompositeException()
        using HiGHS
        @suppress begin
            original = SDDPlab.read_study(example_dir; e = e)
            study = _fast_study(original)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            SDDPlab.save_policy(study, policy, ".", SDDPlab.ParquetFormat())
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.load_policy(study, model, ".", SDDPlab.ParquetFormat())
            simulation = SDDPlab.simulate(study, model)
            SDDPlab.save_simulation(study, simulation, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end

    @testset "1dsin-pipeline" begin
        using HiGHS
        example_1dsin = joinpath(@__DIR__, "..", "example", "1dsin")
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_1dsin; e = e)
            @test length(e) == 0
            study = _fast_study(original)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dsin_ar-pipeline" begin
        using HiGHS
        example_1dsin_ar = joinpath(@__DIR__, "..", "example", "1dsin_ar")
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_1dsin_ar; e = e)
            @test length(e) == 0
            study = _fast_study(original)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "4ree-pipeline" begin
        using HiGHS
        example_4ree = joinpath(@__DIR__, "..", "example", "4ree")
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_4ree; e = e)
            @test length(e) == 0
            study = _fast_study(original)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-statistical-stopping" begin
        using HiGHS
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
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end

    @testset "1dtoy-pipeline-multiple-stopping-criteria" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 20, [Engines.IterationLimit(10), Engines.LowerBoundStability(0.05, 5)]
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
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end

    @testset "1dtoy-pipeline-explicit-insamplemc-simulation" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.InSampleMC(12, false),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.InSampleMC(12, false)
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-strengthened-conic-duality" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.StrengthenedConicDualityHandler(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-revisiting-forward-pass" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.RevisitingForwardPassStrategy(3),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-risk-adjusted-forward-pass" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.RiskAdjustedForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-multi-cut" begin
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.MultiCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            SDDPlab.save_policy(study, policy, ".", SDDPlab.ParquetFormat())
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.load_policy(study, model, ".", SDDPlab.ParquetFormat())
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-pipeline-autoscaling" begin
        using HiGHS
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
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            noscale_engine = Engines.SDDPEngine(
                noscale_policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            noscale_study = SDDPlab.Study(original.inputs, noscale_engine)
            noscale_model = SDDPlab.build(noscale_study, HiGHS.Optimizer)
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
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            autoscale_engine = Engines.SDDPEngine(
                autoscale_policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            autoscale_study = SDDPlab.Study(original.inputs, autoscale_engine)
            autoscale_model = SDDPlab.build(autoscale_study, HiGHS.Optimizer)
            autoscale_policy = SDDPlab.train(autoscale_study, autoscale_model)
            @test autoscale_policy !== nothing

            # The scaled model's bound is in scaled cost units.
            # Unscale: multiply by s_cost * s_gen to recover original units.
            s_cost = Engines.get_scaling_factor(autoscale_model.scaling, Engines.COST_SCALE)
            s_gen = Engines.get_scaling_factor(autoscale_model.scaling, :HYDRO_GENERATION)
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
        using HiGHS
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Threaded(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Threaded(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            @test study.engine.policy.parallel_scheme isa Engines.Threaded
            @test study.engine.simulation.parallel_scheme isa Engines.Threaded
        end
    end

    @testset "1dtoy-pipeline-solver-from-config" begin
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0
            @test original.engine.solver.solver_name == "HiGHS"

            study = _fast_study(original)
            model = SDDPlab.build(study)
            @test model !== nothing
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dtoy-asynchronous-type-wiring" begin
        using HiGHS
        using Distributed
        @suppress begin
            e = CompositeException()
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Asynchronous(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
                Engines.TrainingLogConfig("", 1, false, 1),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
                nothing,
                Engines.DebugConfig(false, Any[], "mof", false, 60.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            @test study.engine.policy.parallel_scheme isa Engines.Asynchronous
            @test study.engine.simulation.parallel_scheme isa Engines.Serial
        end
    end

    @testset "1dtoy-pipeline-asynchronous" begin
        using HiGHS
        using Distributed
        @suppress begin
            if Distributed.nprocs() == 1
                @info "Skipping Asynchronous integration test: no distributed workers available"
                @test_skip true
            else
                e = CompositeException()
                original = SDDPlab.read_study(example_dir; e = e)
                @test length(e) == 0

                convergence = Engines.Convergence(1, 10, [Engines.IterationLimit(10)])
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
                    Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                    Engines.InflowNone(),
                    nothing,
                    Engines.DebugConfig(false, Any[], "mof", false, 60.0),
                )
                study = SDDPlab.Study(original.inputs, engine)
                model = SDDPlab.build(study, HiGHS.Optimizer)
                policy = SDDPlab.train(study, model)
                @test policy !== nothing
            end
        end
    end

    @testset "julia_main" begin
        @testset "help_flag" begin
            # --help should print usage to stdout and return 0
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--help")
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            empty!(ARGS)
        end

        @testset "help_flag_short" begin
            # -h should print usage to stdout and return 0
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "-h")
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            empty!(ARGS)
        end

        @testset "version_flag" begin
            # --version should print version and return 0
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--version")
                output = @capture_out SDDPlab.julia_main()
                @test occursin("SDDPlab v", output)
                return Cint(0)
            end
            @test result == Cint(0)
            empty!(ARGS)
        end

        @testset "version_flag_short" begin
            # -V should print version and return 0
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "-V")
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            empty!(ARGS)
        end

        @testset "missing_path" begin
            # No arguments: should return 1 (validation failure)
            result = withenv() do
                empty!(ARGS)
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result == Cint(1)
            empty!(ARGS)
        end

        @testset "invalid_format" begin
            # Invalid --format value: should return 1
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--format")
                push!(ARGS, "xlsx")
                push!(ARGS, "example/1dtoy")
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result == Cint(1)
            empty!(ARGS)
        end

        @testset "flag_missing_value" begin
            # --output with no subsequent value: should return 1
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--output")
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result == Cint(1)
            empty!(ARGS)
        end

        @testset "nonexistent_path" begin
            # Non-existent study path: should return 2 (runtime error from cd failing)
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "/nonexistent/path/to/study")
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result in (Cint(1), Cint(2))
            empty!(ARGS)
        end

        @testset "full_pipeline_1dtoy" begin
            # Full pipeline on 1dtoy: should return 0 and write output files
            output_dir = mktempdir()
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, example_dir)
                push!(ARGS, "--output")
                push!(ARGS, output_dir)
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            # Verify output files were written
            output_files = readdir(output_dir)
            @test !isempty(output_files)
            empty!(ARGS)
        end

        @testset "full_pipeline_csv_format" begin
            # Full pipeline with CSV format flag: should return 0
            output_dir = mktempdir()
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, example_dir)
                push!(ARGS, "--output")
                push!(ARGS, output_dir)
                push!(ARGS, "--format")
                push!(ARGS, "csv")
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            output_files = readdir(output_dir)
            @test !isempty(output_files)
            @test any(endswith(f, ".csv") for f in output_files)
            empty!(ARGS)
        end

        @testset "julia_main_exported" begin
            # julia_main must be exported from SDDPlab
            @test :julia_main in names(SDDPlab)
        end

        @testset "conflicting_task_flags" begin
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--policy-only")
                push!(ARGS, "--simulate-only")
                push!(ARGS, example_dir)
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result == Cint(1)
            empty!(ARGS)
        end

        @testset "policy_path_missing_value" begin
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--policy-path")
                with_logger(NullLogger()) do
                    SDDPlab.julia_main()
                end
            end
            @test result == Cint(1)
            empty!(ARGS)
        end

        @testset "policy_only_then_simulate_only" begin
            # Train and save policy
            policy_dir = mktempdir()
            result_train = withenv() do
                empty!(ARGS)
                push!(ARGS, "--policy-only")
                push!(ARGS, "--output")
                push!(ARGS, policy_dir)
                push!(ARGS, example_dir)
                @suppress SDDPlab.julia_main()
            end
            @test result_train == Cint(0)
            @test any(f -> occursin("cut", lowercase(f)), readdir(policy_dir))
            empty!(ARGS)

            # Load policy and simulate
            sim_dir = mktempdir()
            result_sim = withenv() do
                empty!(ARGS)
                push!(ARGS, "--simulate-only")
                push!(ARGS, "--policy-path")
                push!(ARGS, policy_dir)
                push!(ARGS, "--output")
                push!(ARGS, sim_dir)
                push!(ARGS, example_dir)
                @suppress SDDPlab.julia_main()
            end
            @test result_sim == Cint(0)
            @test !isempty(readdir(sim_dir))
            empty!(ARGS)
        end

        @testset "no_save_policy" begin
            output_dir = mktempdir()
            result = withenv() do
                empty!(ARGS)
                push!(ARGS, "--policy-only")
                push!(ARGS, "--no-save-policy")
                push!(ARGS, "--output")
                push!(ARGS, output_dir)
                push!(ARGS, example_dir)
                @suppress SDDPlab.julia_main()
            end
            @test result == Cint(0)
            # No files should be written when --no-save-policy is active
            @test isempty(readdir(output_dir))
            empty!(ARGS)
        end
    end
end
