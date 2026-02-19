using SDDPlab: SDDPlab
import SDDPlab: Engines, Lab
using SDDP: SDDP
using HiGHS: HiGHS
using CSV
using DataFrames
using JSON
using Suppressor
using Test

@testset "convergence-analysis" begin
    function make_log(; status=:iteration_limit, entries=[])
        return Engines.TrainingLog(status, entries)
    end

    function make_entry(; iter=1, bound=-100.0, sim=50.0, time=1.0, solves=12, issue=false)
        return Engines.TrainingLogEntry(iter, bound, sim, time, solves, issue)
    end

    @testset "simple-linear-slope" begin
        @testset "perfect-linear" begin
            x = [1.0, 2.0, 3.0, 4.0, 5.0]
            y = [2.0, 4.0, 6.0, 8.0, 10.0]
            slope = Engines._simple_linear_slope(x, y)
            @test isapprox(slope, 2.0; atol=1e-10)
        end

        @testset "negative-slope" begin
            x = [1.0, 2.0, 3.0]
            y = [10.0, 7.0, 4.0]
            slope = Engines._simple_linear_slope(x, y)
            @test isapprox(slope, -3.0; atol=1e-10)
        end

        @testset "single-point-returns-nan" begin
            slope = Engines._simple_linear_slope([1.0], [2.0])
            @test isnan(slope)
        end

        @testset "empty-returns-nan" begin
            slope = Engines._simple_linear_slope(Float64[], Float64[])
            @test isnan(slope)
        end

        @testset "constant-x-returns-nan" begin
            slope = Engines._simple_linear_slope([1.0, 1.0, 1.0], [1.0, 2.0, 3.0])
            @test isnan(slope)
        end
    end

    @testset "compute-gap-trajectory" begin
        @testset "known-values" begin
            entries = [
                make_entry(iter=1, bound=-100.0, sim=200.0, time=0.1),
                make_entry(iter=2, bound=-50.0, sim=100.0, time=0.2),
                make_entry(iter=3, bound=-25.0, sim=50.0, time=0.3),
            ]
            log = make_log(entries=entries)
            df = Engines.compute_gap_trajectory(log)

            @test nrow(df) == 3
            @test names(df) == ["iteration", "bound", "simulation_value", "gap_absolute", "gap_relative"]
            @test df[1, :iteration] == 1
            @test df[1, :bound] == -100.0
            @test df[1, :simulation_value] == 200.0
            @test isapprox(df[1, :gap_absolute], 300.0)
            @test isapprox(df[1, :gap_relative], 300.0 / 100.0)
            @test isapprox(df[2, :gap_absolute], 150.0)
            @test isapprox(df[2, :gap_relative], 150.0 / 50.0)
            @test isapprox(df[3, :gap_absolute], 75.0)
            @test isapprox(df[3, :gap_relative], 75.0 / 25.0)
        end

        @testset "empty-log" begin
            log = make_log(entries=Engines.TrainingLogEntry[])
            df = Engines.compute_gap_trajectory(log)
            @test nrow(df) == 0
            @test names(df) == ["iteration", "bound", "simulation_value", "gap_absolute", "gap_relative"]
        end

        @testset "single-iteration" begin
            entries = [make_entry(iter=1, bound=10.0, sim=20.0)]
            log = make_log(entries=entries)
            df = Engines.compute_gap_trajectory(log)
            @test nrow(df) == 1
            @test isapprox(df[1, :gap_absolute], 10.0)
            @test isapprox(df[1, :gap_relative], 1.0)
        end

        @testset "bound-is-zero-returns-nan" begin
            entries = [make_entry(iter=1, bound=0.0, sim=10.0)]
            log = make_log(entries=entries)
            df = Engines.compute_gap_trajectory(log)
            @test isapprox(df[1, :gap_absolute], 10.0)
            @test isnan(df[1, :gap_relative])
        end

        @testset "10-iterations-decreasing-gap" begin
            entries = [
                make_entry(; iter=i, bound=50.0 + Float64(i) * 10.0, sim=200.0, time=Float64(i))
                for i in 1:10
            ]
            log = make_log(; entries=entries)
            df = Engines.compute_gap_trajectory(log)
            @test nrow(df) == 10
            @test length(names(df)) == 5
            @test all(df[!, :gap_relative] .>= 0)
            @test all(diff(df[!, :gap_relative]) .<= 0)
        end

        @testset "all-gaps-zero" begin
            entries = [
                make_entry(iter=1, bound=50.0, sim=50.0),
                make_entry(iter=2, bound=50.0, sim=50.0),
            ]
            log = make_log(entries=entries)
            df = Engines.compute_gap_trajectory(log)
            @test all(df[!, :gap_absolute] .== 0.0)
            @test all(df[!, :gap_relative] .== 0.0)
        end
    end

    @testset "compute-convergence-rate" begin
        @testset "monotonically-decreasing-gaps" begin
            entries = [
                make_entry(iter=1, bound=100.0, sim=500.0, time=1.0, solves=10),
                make_entry(iter=2, bound=100.0, sim=400.0, time=2.0, solves=20),
                make_entry(iter=3, bound=100.0, sim=300.0, time=3.0, solves=30),
                make_entry(iter=4, bound=100.0, sim=200.0, time=4.0, solves=40),
                make_entry(iter=5, bound=100.0, sim=150.0, time=5.0, solves=50),
                make_entry(iter=6, bound=100.0, sim=120.0, time=6.0, solves=60),
            ]
            log = make_log(entries=entries)
            rate = Engines.compute_convergence_rate(log)

            @test rate["iterations_total"] == 6.0
            @test rate["final_bound"] == 100.0
            @test rate["final_simulation_value"] == 120.0
            @test isapprox(rate["final_gap_relative"], 0.2)
            @test rate["total_time_seconds"] == 6.0
            @test isapprox(rate["time_per_iteration_mean"], 1.0; atol=1e-10)
            @test isapprox(rate["time_per_iteration_std"], 0.0; atol=1e-10)
            @test isapprox(rate["bound_improvement_rate"], 0.0; atol=1e-10)
            @test rate["gap_reduction_rate"] < 0
        end

        @testset "empty-log" begin
            log = make_log(entries=Engines.TrainingLogEntry[])
            rate = Engines.compute_convergence_rate(log)
            @test rate["iterations_total"] == 0.0
            @test isnan(rate["final_bound"])
            @test isnan(rate["gap_reduction_rate"])
            @test rate["total_time_seconds"] == 0.0
        end

        @testset "single-iteration" begin
            entries = [make_entry(iter=1, bound=-100.0, sim=200.0, time=1.5)]
            log = make_log(entries=entries)
            rate = Engines.compute_convergence_rate(log)
            @test rate["iterations_total"] == 1.0
            @test rate["bound_improvement_rate"] == 0.0
            @test rate["total_time_seconds"] == 1.5
            @test rate["final_bound"] == -100.0
        end
    end

    @testset "detect-bound-stationarity" begin
        @testset "stationary-identical-bounds" begin
            entries = [
                make_entry(iter=i, bound=-50.0, sim=-50.0 + 0.1, time=Float64(i))
                for i in 1:25
            ]
            log = make_log(entries=entries)
            result = Engines.detect_bound_stationarity(log; window=20, threshold=1e-6)

            @test result["is_stationary"] == true
            @test result["stationary_since_iteration"] == 1
            @test isapprox(result["bound_range_in_window"], 0.0)
            @test isapprox(result["relative_bound_range"], 0.0)
        end

        @testset "non-stationary-improving-bounds" begin
            entries = [
                make_entry(iter=i, bound=-100.0 + Float64(i) * 5.0, sim=200.0, time=Float64(i))
                for i in 1:25
            ]
            log = make_log(entries=entries)
            result = Engines.detect_bound_stationarity(log; window=20, threshold=1e-6)

            @test result["is_stationary"] == false
            @test result["stationary_since_iteration"] == 0
            @test result["bound_range_in_window"] > 0
        end

        @testset "stationary-with-small-window" begin
            entries = [
                make_entry(iter=i, bound=-50.0, sim=-45.0, time=Float64(i))
                for i in 1:5
            ]
            log = make_log(entries=entries)
            result = Engines.detect_bound_stationarity(log; window=3, threshold=1e-6)
            @test result["is_stationary"] == true
        end

        @testset "empty-log" begin
            log = make_log(entries=Engines.TrainingLogEntry[])
            result = Engines.detect_bound_stationarity(log)
            @test result["is_stationary"] == false
            @test result["stationary_since_iteration"] == 0
            @test isnan(result["bound_range_in_window"])
        end

        @testset "single-iteration" begin
            entries = [make_entry(iter=1, bound=-50.0, sim=-40.0)]
            log = make_log(entries=entries)
            result = Engines.detect_bound_stationarity(log; window=20, threshold=1e-6)
            @test result["is_stationary"] == true
            @test result["stationary_since_iteration"] == 1
            @test isapprox(result["bound_range_in_window"], 0.0)
        end

        @testset "transition-from-improving-to-flat" begin
            entries_improving = [
                make_entry(iter=i, bound=-100.0 + Float64(i) * 9.0, sim=200.0, time=Float64(i))
                for i in 1:10
            ]
            entries_flat = [
                make_entry(iter=10 + i, bound=-10.0, sim=200.0, time=Float64(10 + i))
                for i in 1:20
            ]
            log = make_log(entries=vcat(entries_improving, entries_flat))
            result = Engines.detect_bound_stationarity(log; window=20, threshold=1e-6)

            @test result["is_stationary"] == true
            @test result["bound_range_in_window"] == 0.0
            @test result["stationary_since_iteration"] == 10
        end
    end

    @testset "generate-convergence-report" begin
        @testset "with-numerical-issues" begin
            entries = [
                make_entry(iter=1, bound=-100.0, sim=200.0, time=1.0, issue=false),
                make_entry(iter=2, bound=-80.0, sim=150.0, time=2.0, issue=true),
                make_entry(iter=3, bound=-60.0, sim=110.0, time=3.0, issue=false),
                make_entry(iter=4, bound=-50.0, sim=90.0, time=4.0, issue=true),
            ]
            log = make_log(status=:iteration_limit, entries=entries)
            report = Engines.generate_convergence_report(log)

            @test report["status"] == "iteration_limit"
            @test report["had_numerical_issues"] == true
            @test report["numerical_issue_iterations"] == [2, 4]
            @test haskey(report, "convergence_rate")
            @test haskey(report, "bound_stationarity")
            @test report["convergence_rate"] isa Dict{String,Float64}
            @test report["bound_stationarity"] isa Dict{String,Any}
        end

        @testset "without-numerical-issues" begin
            entries = [
                make_entry(iter=1, bound=-100.0, sim=200.0, time=1.0, issue=false),
                make_entry(iter=2, bound=-80.0, sim=150.0, time=2.0, issue=false),
            ]
            log = make_log(status=:converged, entries=entries)
            report = Engines.generate_convergence_report(log)

            @test report["status"] == "converged"
            @test report["had_numerical_issues"] == false
            @test isempty(report["numerical_issue_iterations"])
        end

        @testset "empty-log-report" begin
            log = make_log(entries=Engines.TrainingLogEntry[])
            report = Engines.generate_convergence_report(log)
            @test report["status"] == "iteration_limit"
            @test report["had_numerical_issues"] == false
            @test isempty(report["numerical_issue_iterations"])
        end

        @testset "report-json-serializable" begin
            entries = [
                make_entry(iter=1, bound=-100.0, sim=200.0, time=1.0),
                make_entry(iter=2, bound=-80.0, sim=150.0, time=2.0),
            ]
            log = make_log(status=:iteration_limit, entries=entries)
            report = Engines.generate_convergence_report(log)

            sanitized = Engines.__sanitize_for_json(report)
            json_str = JSON.json(sanitized)
            @test !isempty(json_str)

            parsed = JSON.parse(json_str)
            @test parsed["status"] == "iteration_limit"
        end
    end

    example_dir = joinpath(@__DIR__, "..", "example", "1dtoy")

    @testset "integration-1dtoy" begin
        @testset "analysis-on-trained-artifact" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e=e)
            @test length(e) == 0

            local artifact
            @suppress begin
                model = SDDPlab.build(study, HiGHS.Optimizer)
                artifact = SDDPlab.train(study, model)
            end

            @test artifact.training_log !== nothing
            log = artifact.training_log

            df = Engines.compute_gap_trajectory(log)
            @test nrow(df) == length(log.iterations)
            @test names(df) == ["iteration", "bound", "simulation_value", "gap_absolute", "gap_relative"]
            @test all(isfinite.(df[!, :gap_absolute]))

            rate = Engines.compute_convergence_rate(log)
            @test rate["iterations_total"] == Float64(length(log.iterations))
            @test rate["total_time_seconds"] >= 0.0
            @test isfinite(rate["final_bound"])
            @test isfinite(rate["final_simulation_value"])

            stationarity = Engines.detect_bound_stationarity(log)
            @test haskey(stationarity, "is_stationary")
            @test haskey(stationarity, "stationary_since_iteration")
            @test haskey(stationarity, "bound_range_in_window")
            @test haskey(stationarity, "relative_bound_range")

            report = Engines.generate_convergence_report(log)
            @test report["status"] isa String
            @test haskey(report, "convergence_rate")
            @test haskey(report, "bound_stationarity")
            @test haskey(report, "had_numerical_issues")
            @test haskey(report, "numerical_issue_iterations")
        end

        @testset "save-policy-writes-convergence-files-csv" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e=e)
            @test length(e) == 0

            mktempdir() do tmpdir
                local artifact
                @suppress begin
                    model = SDDPlab.build(study, HiGHS.Optimizer)
                    artifact = SDDPlab.train(study, model)
                    SDDPlab.save_policy(study, artifact, tmpdir, SDDPlab.CSVFormat())
                end

                analysis_path = joinpath(tmpdir, "convergence_analysis.csv")
                @test isfile(analysis_path)
                df = CSV.read(analysis_path, DataFrame)
                @test "iteration" in names(df)
                @test "bound" in names(df)
                @test "simulation_value" in names(df)
                @test "gap_absolute" in names(df)
                @test "gap_relative" in names(df)
                @test nrow(df) > 0

                report_path = joinpath(tmpdir, "convergence_report.json")
                @test isfile(report_path)
                report = JSON.parsefile(report_path)
                @test haskey(report, "status")
                @test haskey(report, "convergence_rate")
                @test haskey(report, "bound_stationarity")
                @test haskey(report, "had_numerical_issues")
                @test haskey(report, "numerical_issue_iterations")

                @test isfile(joinpath(tmpdir, "cuts.csv"))
                @test isfile(joinpath(tmpdir, "convergence.csv"))
                @test isfile(joinpath(tmpdir, "training_log.csv"))
            end
        end

        @testset "save-policy-writes-convergence-files-parquet" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e=e)
            @test length(e) == 0

            mktempdir() do tmpdir
                @suppress begin
                    model = SDDPlab.build(study, HiGHS.Optimizer)
                    artifact = SDDPlab.train(study, model)
                    SDDPlab.save_policy(study, artifact, tmpdir, SDDPlab.ParquetFormat())
                end

                @test isfile(joinpath(tmpdir, "convergence_analysis.parquet"))
                @test isfile(joinpath(tmpdir, "convergence_report.json"))
            end
        end
    end
end
