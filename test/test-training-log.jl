using SDDPlab: SDDPlab
import SDDPlab: Engines, Lab
using SDDP: SDDP
using HiGHS: HiGHS
using CSV
using DataFrames
using Suppressor
using Test

@testset "training-log" begin
    @testset "config-defaults" begin
        @testset "default-when-no-logging-key" begin
            policy_dict = Dict{String,Any}(
                "convergence" => Dict{String,Any}(
                    "min_iterations" => 1,
                    "max_iterations" => 3,
                    "stopping_criteria" => Dict{String,Any}(
                        "kind" => "IterationLimit",
                        "params" => Dict{String,Any}("num_iterations" => 3),
                    ),
                ),
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
                "parallel_scheme" =>
                    Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            )
            e = CompositeException()
            result = Engines.SDDPPolicyTaskDefinition(policy_dict, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.logging isa Engines.TrainingLogConfig
            @test result.logging.log_file == ""
            @test result.logging.log_frequency == 1
            @test result.logging.log_every_iteration == false
            @test result.logging.print_level == 1
        end

        @testset "all-fields-specified" begin
            logging_dict = Dict{String,Any}(
                "log_file" => "/tmp/test.log",
                "log_frequency" => 5,
                "log_every_iteration" => true,
                "print_level" => 2,
            )
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.log_file == "/tmp/test.log"
            @test result.log_frequency == 5
            @test result.log_every_iteration == true
            @test result.print_level == 2
        end

        @testset "partial-fields-use-defaults" begin
            logging_dict = Dict{String,Any}("log_frequency" => 10)
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.log_file == ""
            @test result.log_frequency == 10
            @test result.log_every_iteration == false
            @test result.print_level == 1
        end
    end

    @testset "config-validation-errors" begin
        @testset "negative-log-frequency" begin
            logging_dict = Dict{String,Any}("log_frequency" => -1)
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "zero-log-frequency" begin
            logging_dict = Dict{String,Any}("log_frequency" => 0)
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "print-level-out-of-range-negative" begin
            logging_dict = Dict{String,Any}("print_level" => -1)
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "print-level-out-of-range-high" begin
            logging_dict = Dict{String,Any}("print_level" => 3)
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-log-frequency-type" begin
            logging_dict = Dict{String,Any}("log_frequency" => "not_a_number")
            e = CompositeException()
            result = Engines.TrainingLogConfig(logging_dict, e)
            @test result === nothing
            @test length(e) > 0
        end
    end

    @testset "config-in-policy-definition" begin
        @testset "policy-with-logging-key" begin
            policy_dict = Dict{String,Any}(
                "convergence" => Dict{String,Any}(
                    "min_iterations" => 1,
                    "max_iterations" => 3,
                    "stopping_criteria" => Dict{String,Any}(
                        "kind" => "IterationLimit",
                        "params" => Dict{String,Any}("num_iterations" => 3),
                    ),
                ),
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
                "parallel_scheme" =>
                    Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
                "logging" => Dict{String,Any}("log_frequency" => 2, "print_level" => 0),
            )
            e = CompositeException()
            result = Engines.SDDPPolicyTaskDefinition(policy_dict, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.logging.log_frequency == 2
            @test result.logging.print_level == 0
        end

        @testset "policy-with-invalid-logging-rejects" begin
            policy_dict = Dict{String,Any}(
                "convergence" => Dict{String,Any}(
                    "min_iterations" => 1,
                    "max_iterations" => 3,
                    "stopping_criteria" => Dict{String,Any}(
                        "kind" => "IterationLimit",
                        "params" => Dict{String,Any}("num_iterations" => 3),
                    ),
                ),
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
                "parallel_scheme" =>
                    Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
                "logging" => Dict{String,Any}("log_frequency" => -5),
            )
            e = CompositeException()
            result = Engines.SDDPPolicyTaskDefinition(policy_dict, e)
            @test result === nothing
            @test length(e) > 0
        end
    end

    @testset "training-log-structs" begin
        @testset "training-log-entry-creation" begin
            entry = Engines.TrainingLogEntry(1, -100.5, 50.2, 0.5, 24, false)
            @test entry.iteration == 1
            @test entry.bound == -100.5
            @test entry.simulation_value == 50.2
            @test entry.time == 0.5
            @test entry.total_solves == 24
            @test entry.serious_numerical_issue == false
        end

        @testset "training-log-creation" begin
            entries = [
                Engines.TrainingLogEntry(1, -100.0, 50.0, 0.1, 12, false),
                Engines.TrainingLogEntry(2, -90.0, 45.0, 0.2, 24, false),
                Engines.TrainingLogEntry(3, -85.0, 42.0, 0.3, 36, true),
            ]
            log = Engines.TrainingLog(:iteration_limit, entries)
            @test log.status == :iteration_limit
            @test length(log.iterations) == 3
            @test log.iterations[1].iteration == 1
            @test log.iterations[3].serious_numerical_issue == true
        end

        @testset "empty-training-log" begin
            log = Engines.TrainingLog(:iteration_limit, Engines.TrainingLogEntry[])
            @test log.status == :iteration_limit
            @test isempty(log.iterations)
        end
    end

    @testset "integration-e2e" begin
        @testset "train-returns-training-log" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            local artifact
            @suppress begin
                model = SDDPlab.build(study, HiGHS.Optimizer)
                artifact = SDDPlab.train(study, model)
            end

            @test artifact isa Engines.SDDPPolicyTaskArtifact
            @test artifact.training_log !== nothing
            @test artifact.training_log isa Engines.TrainingLog
            @test artifact.training_log.status isa Symbol
            @test length(artifact.training_log.iterations) > 0
            @test length(artifact.training_log.iterations) <=
                study.engine.policy.convergence.max_iterations

            first_entry = artifact.training_log.iterations[1]
            @test first_entry.iteration == 1
            @test first_entry.time >= 0.0
            @test first_entry.total_solves > 0
        end

        @testset "save-policy-writes-training-log-csv" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            mktempdir() do tmpdir
                local artifact
                @suppress begin
                    model = SDDPlab.build(study, HiGHS.Optimizer)
                    artifact = SDDPlab.train(study, model)
                    SDDPlab.save_policy(study, artifact, tmpdir, SDDPlab.CSVFormat())
                end

                log_path = joinpath(tmpdir, "training_log.csv")
                @test isfile(log_path)

                df = CSV.read(log_path, DataFrame)
                expected_cols = [
                    "iteration",
                    "bound",
                    "simulation_value",
                    "time",
                    "total_solves",
                    "serious_numerical_issue",
                    "status",
                ]
                for col in expected_cols
                    @test col in names(df)
                end

                @test nrow(df) > 0
                @test nrow(df) <= study.engine.policy.convergence.max_iterations
                @test df[1, "iteration"] == 1
                @test all(df[!, "time"] .>= 0.0)
                @test all(df[!, "total_solves"] .> 0)
            end
        end

        @testset "save-policy-writes-training-log-parquet" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            mktempdir() do tmpdir
                @suppress begin
                    model = SDDPlab.build(study, HiGHS.Optimizer)
                    artifact = SDDPlab.train(study, model)
                    SDDPlab.save_policy(study, artifact, tmpdir, SDDPlab.ParquetFormat())
                end

                log_path = joinpath(tmpdir, "training_log.parquet")
                @test isfile(log_path)
            end
        end

        @testset "save-policy-also-writes-cuts-and-convergence" begin
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            mktempdir() do tmpdir
                @suppress begin
                    model = SDDPlab.build(study, HiGHS.Optimizer)
                    artifact = SDDPlab.train(study, model)
                    SDDPlab.save_policy(study, artifact, tmpdir, SDDPlab.CSVFormat())
                end

                @test isfile(joinpath(tmpdir, "cuts.csv"))
                @test isfile(joinpath(tmpdir, "convergence.csv"))
                @test isfile(joinpath(tmpdir, "training_log.csv"))
            end
        end
    end

    @testset "engine-config-with-logging" begin
        params = Dict{String,Any}(
            "policy" => Dict{String,Any}(
                "convergence" => Dict{String,Any}(
                    "min_iterations" => 1,
                    "max_iterations" => 5,
                    "stopping_criteria" => Dict{String,Any}(
                        "kind" => "IterationLimit",
                        "params" => Dict{String,Any}("num_iterations" => 5),
                    ),
                ),
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
                "parallel_scheme" => Dict{String,Any}(
                    "kind" => "Serial", "params" => Dict{String,Any}()
                ),
                "logging" => Dict{String,Any}(
                    "log_frequency" => 2,
                    "print_level" => 0,
                    "log_every_iteration" => true,
                ),
            ),
            "simulation" => Dict{String,Any}(
                "num_simulated_series" => 10,
                "parallel_scheme" => Dict{String,Any}(
                    "kind" => "Serial", "params" => Dict{String,Any}()
                ),
            ),
        )
        e = CompositeException()
        engine = Engines.SDDPEngine(params, e)
        @test engine !== nothing
        @test length(e) == 0
        @test engine.policy.logging.log_frequency == 2
        @test engine.policy.logging.print_level == 0
        @test engine.policy.logging.log_every_iteration == true
        @test engine.policy.logging.log_file == ""
    end
end
