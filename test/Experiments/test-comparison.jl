using Test
using SDDPlab
using CSV
using DataFrames

_example_dir() = abspath(joinpath(@__DIR__, "..", "..", "example", "1dtoy"))

function _write_two_config_experiment(
    tmpdir::String, example_path::String; max_iterations::Int = 3, num_simulations::Int = 5
)
    example_escaped = replace(abspath(example_path), "\\" => "/")
    results_dir = joinpath(tmpdir, "results")
    results_escaped = replace(results_dir, "\\" => "/")

    content = """
    {
        "base_study": "$example_escaped",
        "output_dir": "$results_escaped",
        "overwrite": true,
        "configurations": {
            "cfg_a": {
                "policy": {
                    "convergence": {
                        "min_iterations": 1,
                        "max_iterations": $max_iterations,
                        "stopping_criteria": {
                            "kind": "IterationLimit",
                            "params": { "num_iterations": $max_iterations }
                        }
                    }
                },
                "simulation": {
                    "num_simulated_series": $num_simulations,
                    "parallel_scheme": { "kind": "Serial", "params": {} }
                }
            },
            "cfg_b": {
                "policy": {
                    "convergence": {
                        "min_iterations": 1,
                        "max_iterations": $max_iterations,
                        "stopping_criteria": {
                            "kind": "IterationLimit",
                            "params": { "num_iterations": $max_iterations }
                        }
                    },
                    "risk_measure": {
                        "kind": "AVaR",
                        "params": { "alpha": 0.5 }
                    }
                },
                "simulation": {
                    "num_simulated_series": $num_simulations,
                    "parallel_scheme": { "kind": "Serial", "params": {} }
                }
            }
        }
    }
    """
    exp_path = joinpath(tmpdir, "experiment.jsonc")
    open(exp_path, "w") do io
        write(io, content)
    end
    return exp_path, results_dir
end

function _write_mock_operation_system(dir::String, stage_costs::Vector{Vector{Float64}})
    mkpath(dir)
    rows = NamedTuple{
        (:stage, :variable_name, :entity_id, :scenario, :value),
        Tuple{Int,String,Int,Int,Float64},
    }[]
    for (scen_idx, stages) in enumerate(stage_costs)
        for (stage_idx, cost) in enumerate(stages)
            push!(
                rows,
                (
                    stage = stage_idx,
                    variable_name = "STAGE_COST",
                    entity_id = 1,
                    scenario = scen_idx,
                    value = cost,
                ),
            )
        end
    end
    CSV.write(joinpath(dir, "operation_system.csv"), rows)
    return nothing
end

@testset "_compute_comparison_statistics" begin
    costs = Float64[100.0, 200.0, 300.0, 400.0, 500.0]
    stats = SDDPlab._compute_comparison_statistics(costs)

    @testset "mean is correct" begin
        @test stats["mean_cost"] ≈ 300.0
    end

    @testset "std is positive" begin
        @test stats["std_cost"] > 0.0
    end

    @testset "CI bounds are ordered correctly" begin
        @test stats["ci_lower_95"] < stats["mean_cost"]
        @test stats["ci_upper_95"] > stats["mean_cost"]
    end

    @testset "p05 <= p50 <= p95" begin
        @test stats["p05_cost"] <= stats["p50_cost"]
        @test stats["p50_cost"] <= stats["p95_cost"]
    end

    @testset "min and max are correct" begin
        @test stats["min_cost"] ≈ 100.0
        @test stats["max_cost"] ≈ 500.0
    end

    @testset "num_simulations matches input length" begin
        @test stats["num_simulations"] == 5.0
    end

    @testset "all expected keys are present" begin
        expected_keys = [
            "mean_cost",
            "std_cost",
            "ci_lower_95",
            "ci_upper_95",
            "p05_cost",
            "p50_cost",
            "p95_cost",
            "min_cost",
            "max_cost",
            "num_simulations",
        ]
        for k in expected_keys
            @test haskey(stats, k)
        end
    end

    @testset "single-element vector: std=0, CI equal to mean" begin
        single = Float64[42.0]
        s = SDDPlab._compute_comparison_statistics(single)
        @test s["std_cost"] == 0.0
        @test s["mean_cost"] ≈ 42.0
        @test s["min_cost"] ≈ 42.0
        @test s["max_cost"] ≈ 42.0
    end
end

@testset "_load_total_costs" begin
    @testset "returns correct sums per scenario from mock CSV" begin
        mktempdir() do tmpdir
            stage_costs = [[10.0, 20.0], [15.0, 25.0]]  # scen1: 30, scen2: 40
            _write_mock_operation_system(tmpdir, stage_costs)

            costs = SDDPlab._load_total_costs(tmpdir)

            @test costs isa Vector{Float64}
            @test length(costs) == 2
            @test costs[1] ≈ 30.0
            @test costs[2] ≈ 40.0
        end
    end

    @testset "returns nothing when no operation_system file exists" begin
        mktempdir() do tmpdir
            result = SDDPlab._load_total_costs(tmpdir)
            @test result === nothing
        end
    end

    @testset "returns empty vector when file exists but has no STAGE_COST rows" begin
        mktempdir() do tmpdir
            rows = [
                (
                    stage = 1,
                    variable_name = "FUTURE_COST",
                    entity_id = 1,
                    scenario = 1,
                    value = 5.0,
                ),
            ]
            CSV.write(joinpath(tmpdir, "operation_system.csv"), rows)
            costs = SDDPlab._load_total_costs(tmpdir)
            @test costs isa Vector{Float64}
            @test isempty(costs)
        end
    end

    @testset "sums correctly across three stages and four scenarios" begin
        mktempdir() do tmpdir
            stage_costs = [
                [10.0, 10.0, 10.0],  # total = 30
                [20.0, 20.0, 20.0],  # total = 60
                [30.0, 30.0, 30.0],  # total = 90
                [40.0, 40.0, 40.0],  # total = 120
            ]
            _write_mock_operation_system(tmpdir, stage_costs)

            costs = SDDPlab._load_total_costs(tmpdir)
            @test length(costs) == 4
            @test costs[1] ≈ 30.0
            @test costs[2] ≈ 60.0
            @test costs[3] ≈ 90.0
            @test costs[4] ≈ 120.0
        end
    end
end

@testset "_read_experiment_timing" begin
    @testset "returns empty dict when summary CSV absent" begin
        mktempdir() do tmpdir
            result = SDDPlab._read_experiment_timing(tmpdir)
            @test isempty(result)
        end
    end

    @testset "reads timing values correctly" begin
        mktempdir() do tmpdir
            rows = [
                (
                    config_name = "cfg_a",
                    success = true,
                    train_time_s = 5.2,
                    simulate_time_s = 1.1,
                    error = "",
                ),
                (
                    config_name = "cfg_b",
                    success = true,
                    train_time_s = 6.8,
                    simulate_time_s = 2.3,
                    error = "",
                ),
            ]
            CSV.write(joinpath(tmpdir, "experiment_summary.csv"), rows)

            timing = SDDPlab._read_experiment_timing(tmpdir)
            @test haskey(timing, "cfg_a")
            @test haskey(timing, "cfg_b")
            train_a, sim_a = timing["cfg_a"]
            @test train_a ≈ 5.2
            @test sim_a ≈ 1.1
            train_b, sim_b = timing["cfg_b"]
            @test train_b ≈ 6.8
            @test sim_b ≈ 2.3
        end
    end
end

@testset "ConfigSummary construction" begin
    stats = Dict{String,Float64}("mean_cost" => 100.0, "std_cost" => 10.0)
    s = ConfigSummary("cfg_a", stats, 5.0, 2.0, 10)
    @test s.config_name == "cfg_a"
    @test s.statistics["mean_cost"] ≈ 100.0
    @test s.train_time_s ≈ 5.0
    @test s.simulate_time_s ≈ 2.0
    @test s.num_scenarios == 10
end

@testset "ComparisonResult construction" begin
    s1 = ConfigSummary("a", Dict{String,Float64}(), 1.0, 0.5, 3)
    s2 = ConfigSummary("b", Dict{String,Float64}(), 2.0, 1.0, 3)
    r = ComparisonResult([s1, s2], "/some/dir")
    @test length(r.summaries) == 2
    @test r.output_dir == "/some/dir"
    @test r.summaries[1].config_name == "a"
    @test r.summaries[2].config_name == "b"
end

@testset "aggregate_experiment_results unit" begin
    @testset "skips directory missing operation_system file with warning" begin
        mktempdir() do tmpdir
            valid_dir = joinpath(tmpdir, "valid_config")
            empty_dir = joinpath(tmpdir, "empty_config")
            mkpath(valid_dir)
            mkpath(empty_dir)
            _write_mock_operation_system(valid_dir, [[50.0, 60.0], [70.0, 80.0]])

            result = aggregate_experiment_results(tmpdir)
            @test length(result.summaries) == 1
            @test result.summaries[1].config_name == "valid_config"
        end
    end

    @testset "returns ComparisonResult with correct output_dir" begin
        mktempdir() do tmpdir
            cfg_dir = joinpath(tmpdir, "cfg1")
            _write_mock_operation_system(cfg_dir, [[10.0], [20.0], [30.0]])
            result = aggregate_experiment_results(tmpdir)
            @test result.output_dir == abspath(tmpdir)
        end
    end

    @testset "timing defaults to NaN when experiment_summary.csv absent" begin
        mktempdir() do tmpdir
            cfg_dir = joinpath(tmpdir, "cfg1")
            _write_mock_operation_system(cfg_dir, [[10.0], [20.0]])
            result = aggregate_experiment_results(tmpdir)
            @test length(result.summaries) == 1
            @test isnan(result.summaries[1].train_time_s)
            @test isnan(result.summaries[1].simulate_time_s)
        end
    end
end

@testset "compare_configs unit" begin
    @testset "returns only specified configs" begin
        mktempdir() do tmpdir
            for name in ["cfg_a", "cfg_b", "cfg_c"]
                dir = joinpath(tmpdir, name)
                _write_mock_operation_system(dir, [[10.0], [20.0]])
            end

            result = compare_configs(tmpdir, ["cfg_a", "cfg_c"])
            @test length(result.summaries) == 2
            names = [s.config_name for s in result.summaries]
            @test "cfg_a" in names
            @test "cfg_c" in names
            @test !("cfg_b" in names)
        end
    end

    @testset "skips missing config dirs with warning" begin
        mktempdir() do tmpdir
            dir_a = joinpath(tmpdir, "cfg_a")
            _write_mock_operation_system(dir_a, [[10.0], [20.0]])

            result = compare_configs(tmpdir, ["cfg_a", "cfg_b"])
            @test length(result.summaries) == 1
            @test result.summaries[1].config_name == "cfg_a"
        end
    end

    @testset "empty config_names returns empty summaries" begin
        mktempdir() do tmpdir
            result = compare_configs(tmpdir, String[])
            @test isempty(result.summaries)
        end
    end
end

@testset "write_comparison unit" begin
    mktempdir() do tmpdir
        # Set up two config directories with known costs
        for (name, costs) in [
            ("cfg_a", [[100.0, 200.0], [150.0, 250.0]]),
            ("cfg_b", [[50.0, 50.0], [60.0, 60.0]]),
        ]
            _write_mock_operation_system(joinpath(tmpdir, name), costs)
        end

        result = aggregate_experiment_results(tmpdir)
        @test length(result.summaries) == 2

        out_dir = joinpath(tmpdir, "comparison_output")
        write_comparison(result, out_dir, CSVFormat())

        @testset "comparison_summary.csv exists with expected columns" begin
            summary_path = joinpath(out_dir, "comparison_summary.csv")
            @test isfile(summary_path)

            df = CSV.read(summary_path, DataFrame)
            @test nrow(df) == 2
            expected_cols = [
                "config_name",
                "mean_cost",
                "std_cost",
                "ci_lower_95",
                "ci_upper_95",
                "p05_cost",
                "p50_cost",
                "p95_cost",
                "min_cost",
                "max_cost",
                "num_scenarios",
                "train_time_s",
                "simulate_time_s",
            ]
            col_set = names(df)
            for col in expected_cols
                @test col in col_set
            end
        end

        @testset "comparison_costs.csv exists with expected columns and correct row count" begin
            costs_path = joinpath(out_dir, "comparison_costs.csv")
            @test isfile(costs_path)

            df = CSV.read(costs_path, DataFrame)
            @test nrow(df) == 4  # 2 configs x 2 scenarios
            @test "config_name" in names(df)
            @test "scenario" in names(df)
            @test "total_cost" in names(df)
        end

        @testset "comparison_costs.csv values are correct" begin
            costs_path = joinpath(out_dir, "comparison_costs.csv")
            df = CSV.read(costs_path, DataFrame)

            cfg_a_rows = filter(r -> r.config_name == "cfg_a", df)
            @test nrow(cfg_a_rows) == 2
            totals_a = sort(cfg_a_rows.total_cost)
            @test totals_a[1] ≈ 300.0  # 100+200
            @test totals_a[2] ≈ 400.0  # 150+250

            cfg_b_rows = filter(r -> r.config_name == "cfg_b", df)
            @test nrow(cfg_b_rows) == 2
            totals_b = sort(cfg_b_rows.total_cost)
            @test totals_b[1] ≈ 100.0  # 50+50
            @test totals_b[2] ≈ 120.0  # 60+60
        end

        @testset "comparison_summary.csv mean_cost values are correct" begin
            summary_path = joinpath(out_dir, "comparison_summary.csv")
            df = CSV.read(summary_path, DataFrame)

            row_a = filter(r -> r.config_name == "cfg_a", df)
            @test nrow(row_a) == 1
            @test row_a.mean_cost[1] ≈ 350.0  # mean([300, 400])

            row_b = filter(r -> r.config_name == "cfg_b", df)
            @test nrow(row_b) == 1
            @test row_b.mean_cost[1] ≈ 110.0  # mean([100, 120])
        end
    end
end

@testset "aggregate_experiment_results integration" begin
    example = _example_dir()

    @testset "2-config experiment produces valid ComparisonResult and output files" begin
        mktempdir() do tmpdir
            exp_path, results_dir = _write_two_config_experiment(
                tmpdir, example; max_iterations = 3, num_simulations = 5
            )

            exp_results = run_experiment(exp_path)
            @test all(r.success for r in exp_results)

            comparison = aggregate_experiment_results(results_dir)

            @test comparison isa ComparisonResult
            @test length(comparison.summaries) == 2
            @test comparison.output_dir == abspath(results_dir)

            for s in comparison.summaries
                @test s.config_name in ["cfg_a", "cfg_b"]
                @test s.num_scenarios == 5
                @test !isnan(s.statistics["mean_cost"])
                @test !isnan(s.statistics["std_cost"])
                @test s.statistics["min_cost"] <= s.statistics["mean_cost"]
                @test s.statistics["mean_cost"] <= s.statistics["max_cost"]
                @test s.statistics["ci_lower_95"] <= s.statistics["ci_upper_95"]
                @test s.train_time_s >= 0.0
                @test s.simulate_time_s >= 0.0
            end

            write_comparison(comparison, results_dir, CSVFormat())

            summary_path = joinpath(results_dir, "comparison_summary.csv")
            @test isfile(summary_path)
            df_summary = CSV.read(summary_path, DataFrame)
            @test nrow(df_summary) == 2
            @test "config_name" in names(df_summary)
            @test "mean_cost" in names(df_summary)
            @test "num_scenarios" in names(df_summary)

            costs_path = joinpath(results_dir, "comparison_costs.csv")
            @test isfile(costs_path)
            df_costs = CSV.read(costs_path, DataFrame)
            @test nrow(df_costs) == 10  # 2 configs x 5 scenarios
            @test "config_name" in names(df_costs)
            @test "scenario" in names(df_costs)
            @test "total_cost" in names(df_costs)

            @test all(isfinite, df_costs.total_cost)
            @test all(>(0), df_costs.total_cost)
        end
    end

    @testset "compare_configs returns only 1 summary when 1 config name given" begin
        mktempdir() do tmpdir
            exp_path, results_dir = _write_two_config_experiment(
                tmpdir, example; max_iterations = 3, num_simulations = 4
            )
            run_experiment(exp_path)

            result = compare_configs(results_dir, ["cfg_a"])
            @test length(result.summaries) == 1
            @test result.summaries[1].config_name == "cfg_a"
            @test result.summaries[1].num_scenarios == 4
        end
    end
end
