using Test
using SDDPlab
using CSV

_example_dir() = abspath(joinpath(@__DIR__, "..", "..", "example", "1dtoy"))

function _valid_experiment_dict(base_study_rel)
    return Dict{String,Any}(
        "base_study" => base_study_rel,
        "configurations" => Dict{String,Any}(
            "cfg_a" => Dict{String,Any}(
                "policy" => Dict{String,Any}(
                    "convergence" => Dict{String,Any}(
                        "max_iterations" => 3,
                        "stopping_criteria" => Dict{String,Any}(
                            "kind" => "IterationLimit",
                            "params" => Dict{String,Any}("num_iterations" => 3),
                        ),
                    ),
                ),
            ),
        ),
    )
end

function _write_experiment_jsonc(dir::String, content::String)
    path = joinpath(dir, "experiment.jsonc")
    open(path, "w") do io
        write(io, content)
    end
    return path
end

@testset "deep_merge" begin
    @testset "non-overlapping keys are unioned" begin
        base = Dict{String,Any}("a" => 1)
        over = Dict{String,Any}("b" => 2)
        r = SDDPlab.deep_merge(base, over)
        @test r["a"] == 1
        @test r["b"] == 2
    end

    @testset "override wins for scalar values" begin
        base = Dict{String,Any}("x" => 10)
        over = Dict{String,Any}("x" => 99)
        r = SDDPlab.deep_merge(base, over)
        @test r["x"] == 99
    end

    @testset "nested dicts are merged recursively" begin
        base = Dict{String,Any}(
            "policy" => Dict{String,Any}("alpha" => 0.5, "beta" => 1.0),
        )
        over = Dict{String,Any}(
            "policy" => Dict{String,Any}("alpha" => 0.1),
        )
        r = SDDPlab.deep_merge(base, over)
        @test r["policy"]["alpha"] == 0.1   # overridden
        @test r["policy"]["beta"] == 1.0    # inherited from base
    end

    @testset "empty override returns copy of base" begin
        base = Dict{String,Any}("a" => 1, "b" => Dict{String,Any}("c" => 3))
        over = Dict{String,Any}()
        r = SDDPlab.deep_merge(base, over)
        @test r == base
        @test r !== base   # new dict, not same object
    end

    @testset "base not mutated" begin
        base = Dict{String,Any}("x" => 1)
        over = Dict{String,Any}("x" => 2)
        SDDPlab.deep_merge(base, over)
        @test base["x"] == 1
    end

    @testset "scalar over dict wins (override wins)" begin
        base = Dict{String,Any}("policy" => Dict{String,Any}("a" => 1))
        over = Dict{String,Any}("policy" => "flat")
        r = SDDPlab.deep_merge(base, over)
        @test r["policy"] == "flat"
    end
end

@testset "read_experiment_config" begin
    example = _example_dir()

    mktempdir() do tmpdir
        @testset "valid config parses successfully" begin
            content = """
            {
                "base_study": "$(replace(example, "\\" => "/"))",
                "output_dir": "results",
                "configurations": {
                    "cfg1": {
                        "policy": {
                            "convergence": {
                                "max_iterations": 3,
                                "stopping_criteria": {
                                    "kind": "IterationLimit",
                                    "params": { "num_iterations": 3 }
                                }
                            }
                        }
                    }
                }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            cfg = read_experiment_config(path)
            @test cfg isa ExperimentConfig
            @test cfg.base_study_path == example
            @test length(cfg.configurations) == 1
            @test cfg.configurations[1][1] == "cfg1"
        end

        @testset "missing base_study throws" begin
            content = """
            {
                "configurations": { "x": {} }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            @test_throws CompositeException read_experiment_config(path)
        end

        @testset "missing configurations throws" begin
            content = """
            {
                "base_study": "$(replace(example, "\\" => "/"))"
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            @test_throws CompositeException read_experiment_config(path)
        end

        @testset "base_study not a directory throws" begin
            content = """
            {
                "base_study": "/nonexistent/path/does/not/exist",
                "configurations": { "x": {} }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            @test_throws CompositeException read_experiment_config(path)
        end

        @testset "invalid config name with slash throws" begin
            content = """
            {
                "base_study": "$(replace(example, "\\" => "/"))",
                "configurations": {
                    "bad/name": {}
                }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            @test_throws CompositeException read_experiment_config(path)
        end

        @testset "invalid config name with space throws" begin
            content = """
            {
                "base_study": "$(replace(example, "\\" => "/"))",
                "configurations": {
                    "bad name": {}
                }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            @test_throws CompositeException read_experiment_config(path)
        end

        @testset "overwrite flag defaults to false" begin
            content = """
            {
                "base_study": "$(replace(example, "\\" => "/"))",
                "configurations": { "cfg1": {} }
            }
            """
            path = _write_experiment_jsonc(tmpdir, content)
            cfg = read_experiment_config(path)
            @test cfg.overwrite == false
        end

        @testset "relative base_study resolved against experiment dir" begin
            # Place the experiment.jsonc one level above the example dir
            parent_dir = dirname(example)
            example_basename = basename(example)
            content = """
            {
                "base_study": "$(example_basename)",
                "configurations": { "cfg1": {} }
            }
            """
            exp_path = joinpath(parent_dir, "experiment_rel_test.jsonc")
            try
                open(exp_path, "w") do io
                    write(io, content)
                end
                cfg = read_experiment_config(exp_path)
                @test cfg.base_study_path == abspath(example)
            finally
                isfile(exp_path) && rm(exp_path)
            end
        end
    end
end

@testset "run_experiment integration" begin
    example = _example_dir()
    example_escaped = replace(example, "\\" => "/")

    @testset "two successful configs produce output directories and summary CSV" begin
        mktempdir() do tmpdir
            content = """
            {
                "base_study": "$example_escaped",
                "output_dir": "$(replace(joinpath(tmpdir, "results"), "\\" => "/"))",
                "overwrite": true,
                "configurations": {
                    "iter5": {
                        "policy": {
                            "convergence": {
                                "min_iterations": 2,
                                "max_iterations": 5,
                                "stopping_criteria": {
                                    "kind": "IterationLimit",
                                    "params": { "num_iterations": 5 }
                                }
                            }
                        },
                        "simulation": {
                            "num_simulated_series": 5,
                            "parallel_scheme": {
                                "kind": "Serial",
                                "params": {}
                            }
                        }
                    },
                    "iter3": {
                        "policy": {
                            "convergence": {
                                "min_iterations": 1,
                                "max_iterations": 3,
                                "stopping_criteria": {
                                    "kind": "IterationLimit",
                                    "params": { "num_iterations": 3 }
                                }
                            }
                        },
                        "simulation": {
                            "num_simulated_series": 3,
                            "parallel_scheme": {
                                "kind": "Serial",
                                "params": {}
                            }
                        }
                    }
                }
            }
            """
            exp_path = _write_experiment_jsonc(tmpdir, content)
            results = run_experiment(exp_path)

            @test length(results) == 2

            for r in results
                @test r.success
                @test r.error_message === nothing
                @test isdir(r.output_path)
                @test r.train_elapsed_seconds >= 0.0
                @test r.simulate_elapsed_seconds >= 0.0
            end

            summary_path = joinpath(tmpdir, "results", "experiment_summary.csv")
            @test isfile(summary_path)

            import_csv = CSV.File(summary_path)
            @test length(import_csv) == 2
            col_names = propertynames(import_csv)
            @test :config_name in col_names
            @test :success in col_names
            @test :train_time_s in col_names
            @test :simulate_time_s in col_names
            @test :error in col_names

            successes = [row.success for row in import_csv]
            @test all(successes)
        end
    end

    @testset "one valid + one invalid config: valid succeeds, invalid fails, summary correct" begin
        mktempdir() do tmpdir
            content = """
            {
                "base_study": "$example_escaped",
                "output_dir": "$(replace(joinpath(tmpdir, "results"), "\\" => "/"))",
                "overwrite": true,
                "configurations": {
                    "good_config": {
                        "policy": {
                            "convergence": {
                                "min_iterations": 1,
                                "max_iterations": 3,
                                "stopping_criteria": {
                                    "kind": "IterationLimit",
                                    "params": { "num_iterations": 3 }
                                }
                            }
                        },
                        "simulation": {
                            "num_simulated_series": 2,
                            "parallel_scheme": {
                                "kind": "Serial",
                                "params": {}
                            }
                        }
                    },
                    "bad_config": {
                        "policy": {
                            "convergence": {
                                "min_iterations": 1,
                                "max_iterations": 3,
                                "stopping_criteria": {
                                    "kind": "NonExistentStoppingCriteria",
                                    "params": {}
                                }
                            }
                        }
                    }
                }
            }
            """
            exp_path = _write_experiment_jsonc(tmpdir, content)
            results = run_experiment(exp_path)

            @test length(results) == 2

            good = findfirst(r -> r.config_name == "good_config", results)
            bad  = findfirst(r -> r.config_name == "bad_config",  results)

            @test good !== nothing
            @test bad  !== nothing

            @test results[good].success == true
            @test results[good].error_message === nothing
            @test isdir(results[good].output_path)

            @test results[bad].success == false
            @test results[bad].error_message isa String
            @test !isempty(results[bad].error_message)

            summary_path = joinpath(tmpdir, "results", "experiment_summary.csv")
            @test isfile(summary_path)

            import_csv = CSV.File(summary_path)
            @test length(import_csv) == 2

            by_name = Dict(row.config_name => row.success for row in import_csv)
            @test by_name["good_config"] == true
            @test by_name["bad_config"]  == false
        end
    end

    @testset "non-empty output dir without overwrite errors" begin
        mktempdir() do tmpdir
            results_dir = joinpath(tmpdir, "results")
            mkpath(results_dir)
            open(joinpath(results_dir, "existing_file.txt"), "w") do io
                write(io, "content")
            end

            content = """
            {
                "base_study": "$example_escaped",
                "output_dir": "$(replace(results_dir, "\\" => "/"))",
                "overwrite": false,
                "configurations": {
                    "cfg1": {}
                }
            }
            """
            exp_path = _write_experiment_jsonc(tmpdir, content)
            @test_throws Exception run_experiment(exp_path)
        end
    end

    @testset "non-empty output dir with overwrite true succeeds" begin
        mktempdir() do tmpdir
            results_dir = joinpath(tmpdir, "results")
            mkpath(results_dir)
            open(joinpath(results_dir, "existing_file.txt"), "w") do io
                write(io, "content")
            end

            content = """
            {
                "base_study": "$example_escaped",
                "output_dir": "$(replace(results_dir, "\\" => "/"))",
                "overwrite": true,
                "configurations": {
                    "cfg1": {
                        "policy": {
                            "convergence": {
                                "min_iterations": 1,
                                "max_iterations": 2,
                                "stopping_criteria": {
                                    "kind": "IterationLimit",
                                    "params": { "num_iterations": 2 }
                                }
                            }
                        },
                        "simulation": {
                            "num_simulated_series": 2,
                            "parallel_scheme": {
                                "kind": "Serial",
                                "params": {}
                            }
                        }
                    }
                }
            }
            """
            exp_path = _write_experiment_jsonc(tmpdir, content)
            results = run_experiment(exp_path)
            @test length(results) == 1
            @test results[1].success
        end
    end
end
