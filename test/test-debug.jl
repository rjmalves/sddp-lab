using SDDPlab: SDDPlab
import SDDPlab: Engines, Lab
using SDDP: SDDP
using JuMP: JuMP
using HiGHS: HiGHS
using JSON
using Suppressor
using Test

@testset "debug" begin
    function _base_engine_dict()
        policy_dict = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 1,
                "max_iterations" => 3,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 3),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        simulation_dict = Dict{String,Any}(
            "num_simulated_series" => 10,
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        return Dict{String,Any}("policy" => policy_dict, "simulation" => simulation_dict)
    end

    @testset "debug-config-defaults-no-key" begin
        params = _base_engine_dict()
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.debug isa Engines.DebugConfig
        @test result.debug.write_subproblems == false
        @test result.debug.subproblem_nodes == Any[]
        @test result.debug.subproblem_format == "mof"
        @test result.debug.deterministic_equivalent == false
        @test result.debug.det_equiv_time_limit == 60.0
    end

    @testset "debug-config-all-fields" begin
        params = _base_engine_dict()
        params["debug"] = Dict{String,Any}(
            "write_subproblems" => true,
            "subproblem_nodes" => [1, 2],
            "subproblem_format" => "lp",
            "deterministic_equivalent" => true,
            "det_equiv_time_limit" => 120.0,
        )
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.debug.write_subproblems == true
        @test result.debug.subproblem_nodes == Any[1, 2]
        @test result.debug.subproblem_format == "lp"
        @test result.debug.deterministic_equivalent == true
        @test result.debug.det_equiv_time_limit == 120.0
    end

    @testset "debug-config-partial-fields" begin
        params = _base_engine_dict()
        params["debug"] = Dict{String,Any}("write_subproblems" => true)
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.debug.write_subproblems == true
        @test result.debug.subproblem_format == "mof"
        @test result.debug.deterministic_equivalent == false
        @test result.debug.det_equiv_time_limit == 60.0
    end

    @testset "debug-config-invalid-format" begin
        params = _base_engine_dict()
        params["debug"] = Dict{String,Any}("subproblem_format" => "csv")
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "debug-config-negative-time-limit" begin
        params = _base_engine_dict()
        params["debug"] = Dict{String,Any}("det_equiv_time_limit" => -10.0)
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "debug-config-mps-format" begin
        params = _base_engine_dict()
        params["debug"] = Dict{String,Any}("subproblem_format" => "mps")
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.debug.subproblem_format == "mps"
    end

    @testset "debug-config-invalid-dict-type" begin
        params = _base_engine_dict()
        params["debug"] = "not a dict"
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "format-extension" begin
        @test Engines._format_extension("mof") == ".mof.json"
        @test Engines._format_extension("lp") == ".lp"
        @test Engines._format_extension("mps") == ".mps"
        @test Engines._format_extension("unknown") == ".mof.json"
    end

    @testset "node-id-to-string" begin
        @test Engines._node_id_to_string(1) == "1"
        @test Engines._node_id_to_string(42) == "42"
        @test Engines._node_id_to_string((1, 2)) == "1_2"
        @test Engines._node_id_to_string((3, 1)) == "3_1"
    end

    example_dir = joinpath(@__DIR__, "..", "example", "1dtoy")

    @testset "integration-write-subproblems-mof" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(true, Any[], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)

            subproblem_files = filter(
                f -> startswith(f, "subproblem_") && endswith(f, ".mof.json"),
                readdir(debug_dir),
            )
            @test length(subproblem_files) > 0

            summary_path = joinpath(debug_dir, "debug_summary.json")
            @test isfile(summary_path)
            summary = JSON.parsefile(summary_path)
            @test summary["write_subproblems"] == true
            @test summary["subproblem_format"] == "mof"
            @test summary["deterministic_equivalent"] == false
            @test length(summary["written_files"]) > 0
            @test isempty(summary["errors"])
        end
    end

    @testset "integration-write-subproblems-filtered-nodes" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(true, Any[2, 3], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)

            subproblem_files = filter(
                f -> startswith(f, "subproblem_") && endswith(f, ".mof.json"),
                readdir(debug_dir),
            )
            @test length(subproblem_files) == 2
            @test "subproblem_2.mof.json" in subproblem_files
            @test "subproblem_3.mof.json" in subproblem_files
        end
    end

    @testset "integration-deterministic-equivalent-fresh-model" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            # SDDP.deterministic_equivalent requires an untrained model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
            end

            debug_cfg = Engines.DebugConfig(false, Any[], "mof", true, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)

            det_path = joinpath(debug_dir, "deterministic_equivalent.mof.json")
            @test isfile(det_path)

            summary = JSON.parsefile(joinpath(debug_dir, "debug_summary.json"))
            @test summary["deterministic_equivalent"] == true
            @test length(summary["written_files"]) == 1
            @test isempty(summary["errors"])
        end
    end

    @testset "integration-deterministic-equivalent-trained-model-error-captured" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            # SDDP.deterministic_equivalent fails on trained models; verify the error is captured
            debug_cfg = Engines.DebugConfig(false, Any[], "mof", true, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)

            summary = JSON.parsefile(joinpath(debug_dir, "debug_summary.json"))
            @test summary["deterministic_equivalent"] == true
            @test length(summary["errors"]) == 1
            @test summary["errors"][1]["step"] == "deterministic_equivalent"
            @test length(summary["written_files"]) == 0
        end
    end

    @testset "integration-write-subproblems-lp-format" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(true, Any[], "lp", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            subproblem_files = filter(
                f -> startswith(f, "subproblem_") && endswith(f, ".lp"), readdir(debug_dir)
            )
            @test length(subproblem_files) > 0
        end
    end

    @testset "integration-noop-default-config" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(false, Any[], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test !isdir(debug_dir)
        end
    end

    @testset "integration-study-debug-function" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(true, Any[], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )
            study = SDDPlab.Study(original.inputs, engine)

            @suppress SDDPlab.debug(study, model, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)
            @test isfile(joinpath(debug_dir, "debug_summary.json"))
        end
    end

    @testset "integration-summary-json-content" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
                SDDPlab.train(original, model)
            end

            debug_cfg = Engines.DebugConfig(true, Any[2], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            summary = JSON.parsefile(joinpath(tmpdir, "debug", "debug_summary.json"))
            @test summary["write_subproblems"] == true
            @test summary["subproblem_format"] == "mof"
            @test summary["deterministic_equivalent"] == false
            @test summary["det_equiv_time_limit"] == 60.0
            @test summary["subproblem_nodes_filter"] == [2]
            @test length(summary["written_files"]) == 1
            @test isempty(summary["errors"])
            @test haskey(summary, "elapsed_time")
            @test summary["elapsed_time"] >= 0.0
        end
    end

    @testset "integration-error-recovery-invalid-node" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        mktempdir() do tmpdir
            local model
            @suppress begin
                model = SDDPlab.build(original, HiGHS.Optimizer)
            end

            debug_cfg = Engines.DebugConfig(true, Any[2, 9999], "mof", false, 60.0)
            engine = Engines.SDDPEngine(
                original.engine.policy,
                original.engine.simulation,
                original.engine.diagnostics,
                original.engine.solver,
                original.engine.inflow_non_negativity,
                original.engine.validation,
                debug_cfg,
            )

            @suppress Lab.debug(model, engine, tmpdir)

            debug_dir = joinpath(tmpdir, "debug")
            @test isdir(debug_dir)

            valid_file = joinpath(debug_dir, "subproblem_2.mof.json")
            @test isfile(valid_file)

            summary = JSON.parsefile(joinpath(debug_dir, "debug_summary.json"))
            @test length(summary["written_files"]) >= 1
            @test haskey(summary, "elapsed_time")
        end
    end
end
