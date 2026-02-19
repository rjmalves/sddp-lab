import SDDPlab: Engines

using Dates
using DataFrames
using JSON
using Statistics
using Suppressor
using SDDP: SDDP

CONVERGENCE_DICT_VAL = Dict{String,Any}(
    "min_iterations" => 5,
    "max_iterations" => 5,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "IterationLimit",
        "params" => Dict{String,Any}("num_iterations" => 5),
    ),
)

RISK_MEASURE_DICT_VAL = Dict{String,Any}(
    "kind" => "Expectation", "params" => Dict{String,Any}()
)

PARALLEL_SCHEME_DICT_VAL =
    Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}())

POLICY_DICT_VAL = Dict{String,Any}(
    "convergence" => CONVERGENCE_DICT_VAL,
    "risk_measure" => RISK_MEASURE_DICT_VAL,
    "parallel_scheme" => PARALLEL_SCHEME_DICT_VAL,
)

SIMULATION_DICT_VAL = Dict{String,Any}(
    "num_simulated_series" => 10,
    "parallel_scheme" => PARALLEL_SCHEME_DICT_VAL,
)

VALIDATION_DICT = Dict{String,Any}(
    "num_simulations" => 50,
    "seed" => 99999,
    "branchings" => 20,
    "parallel_scheme" => Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
)

ENGINE_DICT_WITH_VALIDATION = Dict{String,Any}(
    "engine" => Dict{String,Any}(
        "kind" => "SDDPEngine",
        "params" => Dict{String,Any}(
            "policy" => deepcopy(POLICY_DICT_VAL),
            "simulation" => deepcopy(SIMULATION_DICT_VAL),
            "validation" => deepcopy(VALIDATION_DICT),
        ),
    ),
)

ENGINE_DICT_WITHOUT_VALIDATION = Dict{String,Any}(
    "engine" => Dict{String,Any}(
        "kind" => "SDDPEngine",
        "params" => Dict{String,Any}(
            "policy" => deepcopy(POLICY_DICT_VAL),
            "simulation" => deepcopy(SIMULATION_DICT_VAL),
        ),
    ),
)

@testset "validation" begin
    @testset "validation-constructor" begin
        @testset "valid-config" begin
            d = deepcopy(VALIDATION_DICT)
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result !== nothing
            @test result isa Engines.OutOfSampleValidation
            @test result.num_simulations == 50
            @test result.seed == 99999
            @test result.branchings == 20
            @test result.parallel_scheme isa Engines.Serial
            @test length(e) == 0
        end

        @testset "missing-num-simulations" begin
            d = deepcopy(VALIDATION_DICT)
            delete!(d, "num_simulations")
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "missing-seed" begin
            d = deepcopy(VALIDATION_DICT)
            delete!(d, "seed")
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "missing-branchings" begin
            d = deepcopy(VALIDATION_DICT)
            delete!(d, "branchings")
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-num-simulations-zero" begin
            d = deepcopy(VALIDATION_DICT)
            d["num_simulations"] = 0
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-num-simulations-negative" begin
            d = deepcopy(VALIDATION_DICT)
            d["num_simulations"] = -1
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-seed-zero" begin
            d = deepcopy(VALIDATION_DICT)
            d["seed"] = 0
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-branchings-negative" begin
            d = deepcopy(VALIDATION_DICT)
            d["branchings"] = -5
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "missing-parallel-scheme" begin
            d = deepcopy(VALIDATION_DICT)
            delete!(d, "parallel_scheme")
            e = CompositeException()
            result = Engines.OutOfSampleValidation(d, e)
            # parallel_scheme is required
            @test result === nothing
            @test length(e) > 0
        end
    end

    @testset "engine-with-validation" begin
        @testset "engine-has-6-fields-with-validation" begin
            d = deepcopy(ENGINE_DICT_WITH_VALIDATION)
            e = CompositeException()
            Engines.__build_engine!(d, e)
            @test length(e) == 0
            engine = d["engine"]
            @test engine isa Engines.SDDPEngine
            @test engine.validation !== nothing
            @test engine.validation isa Engines.OutOfSampleValidation
            @test engine.validation.num_simulations == 50
            @test engine.validation.seed == 99999
            @test engine.validation.branchings == 20
        end

        @testset "engine-has-nothing-validation-without-key" begin
            d = deepcopy(ENGINE_DICT_WITHOUT_VALIDATION)
            e = CompositeException()
            Engines.__build_engine!(d, e)
            @test length(e) == 0
            engine = d["engine"]
            @test engine isa Engines.SDDPEngine
            @test engine.validation === nothing
        end

        @testset "engine-invalid-validation-dict" begin
            d = deepcopy(ENGINE_DICT_WITH_VALIDATION)
            d["engine"]["params"]["validation"] = "not a dict"
            e = CompositeException()
            result = Engines.__build_engine!(d, e)
            @test result == false
            @test length(e) > 0
        end

        @testset "engine-invalid-validation-fields" begin
            d = deepcopy(ENGINE_DICT_WITH_VALIDATION)
            d["engine"]["params"]["validation"]["num_simulations"] = -1
            e = CompositeException()
            result = Engines.__build_engine!(d, e)
            @test result == false
            @test length(e) > 0
        end
    end

    @testset "get-validation-definition" begin
        @testset "with-validation" begin
            d = deepcopy(ENGINE_DICT_WITH_VALIDATION)
            e = CompositeException()
            Engines.__build_engine!(d, e)
            engine = d["engine"]::Engines.SDDPEngine
            val = Engines.get_validation_definition(engine)
            @test val !== nothing
            @test val isa Engines.OutOfSampleValidation
        end

        @testset "without-validation" begin
            d = deepcopy(ENGINE_DICT_WITHOUT_VALIDATION)
            e = CompositeException()
            Engines.__build_engine!(d, e)
            engine = d["engine"]::Engines.SDDPEngine
            val = Engines.get_validation_definition(engine)
            @test val === nothing
        end
    end

    @testset "statistics-computation" begin
        @testset "known-values" begin
            # Create mock simulation results with known TOTAL_COST
            # 5 simulations, each with 2 stages
            sims = Vector{Vector{Dict{Symbol,Any}}}()
            costs_per_sim = [100.0, 200.0, 300.0, 400.0, 500.0]
            for total in costs_per_sim
                sim = Vector{Dict{Symbol,Any}}()
                # Split total cost across 2 stages (60/40 split)
                push!(sim, Dict{Symbol,Any}(Symbol("TOTAL_COST") => total * 0.6))
                push!(sim, Dict{Symbol,Any}(Symbol("TOTAL_COST") => total * 0.4))
                push!(sims, sim)
            end

            stats = Engines._compute_validation_statistics(sims)

            # mean = 300
            @test stats["mean_cost"] == 300.0
            # std = std([100, 200, 300, 400, 500]) = sqrt(25000/4) = sqrt(6250) ~= 158.114
            expected_std = std(costs_per_sim)
            @test isapprox(stats["std_cost"], expected_std; atol = 1e-6)
            # num_simulations = 5
            @test stats["num_simulations"] == 5.0
            # max = 500, min = 100
            @test stats["max_cost"] == 500.0
            @test stats["min_cost"] == 100.0
            # median = 300
            @test stats["p50_cost"] == 300.0
            # p05 = quantile([100,200,300,400,500], 0.05) = 116.0
            @test isapprox(stats["p05_cost"], quantile(costs_per_sim, 0.05); atol = 1e-6)
            # p95 = quantile([100,200,300,400,500], 0.95) = 484.0
            @test isapprox(stats["p95_cost"], quantile(costs_per_sim, 0.95); atol = 1e-6)
            # 95% CI: n=5, df=4, t=2.776
            se = expected_std / sqrt(5.0)
            @test isapprox(stats["ci_lower_95"], 300.0 - 2.776 * se; atol = 1e-2)
            @test isapprox(stats["ci_upper_95"], 300.0 + 2.776 * se; atol = 1e-2)
        end

        @testset "single-simulation" begin
            sims = Vector{Vector{Dict{Symbol,Any}}}()
            sim = Vector{Dict{Symbol,Any}}()
            push!(sim, Dict{Symbol,Any}(Symbol("TOTAL_COST") => 42.0))
            push!(sims, sim)

            stats = Engines._compute_validation_statistics(sims)
            @test stats["mean_cost"] == 42.0
            @test stats["std_cost"] == 0.0
            @test stats["num_simulations"] == 1.0
            @test stats["max_cost"] == 42.0
            @test stats["min_cost"] == 42.0
        end

        @testset "large-sample-uses-z" begin
            # 50 simulations -- should use z=1.96
            sims = Vector{Vector{Dict{Symbol,Any}}}()
            for i in 1:50
                sim = [Dict{Symbol,Any}(Symbol("TOTAL_COST") => Float64(i * 10))]
                push!(sims, sim)
            end

            stats = Engines._compute_validation_statistics(sims)
            costs = Float64[i * 10 for i in 1:50]
            mu = mean(costs)
            sigma = std(costs)
            se = sigma / sqrt(50)
            @test isapprox(stats["ci_lower_95"], mu - 1.96 * se; atol = 1e-6)
            @test isapprox(stats["ci_upper_95"], mu + 1.96 * se; atol = 1e-6)
        end
    end

    @testset "t-quantile" begin
        @test Engines._t_quantile_95(1) == 12.706
        @test Engines._t_quantile_95(4) == 2.776
        @test Engines._t_quantile_95(29) == 2.045
        @test Engines._t_quantile_95(30) == 1.96
        @test Engines._t_quantile_95(100) == 1.96
    end

    @testset "integration" begin
        @testset "validate-with-1dtoy" begin
            using HiGHS

            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            @suppress begin
                model = SDDPlab.build(study)
                SDDPlab.train(study, model)

                # Create a validation config manually and run validate via Lab
                validation = Engines.OutOfSampleValidation(10, 99999, 20, Engines.Serial())
                artifact = SDDPlab.Lab.validate(model, validation, study.inputs.files)

                @test artifact isa Engines.SDDPValidationTaskArtifact
                @test length(artifact.simulations) == 10
                @test haskey(artifact.statistics, "mean_cost")
                @test haskey(artifact.statistics, "std_cost")
                @test haskey(artifact.statistics, "ci_lower_95")
                @test haskey(artifact.statistics, "ci_upper_95")
                @test haskey(artifact.statistics, "p05_cost")
                @test haskey(artifact.statistics, "p50_cost")
                @test haskey(artifact.statistics, "p95_cost")
                @test haskey(artifact.statistics, "max_cost")
                @test haskey(artifact.statistics, "min_cost")
                @test haskey(artifact.statistics, "num_simulations")
                @test artifact.statistics["num_simulations"] == 10.0
            end
        end

        @testset "save-validation" begin
            using HiGHS

            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)

            @suppress begin
                model = SDDPlab.build(study)
                SDDPlab.train(study, model)

                validation = Engines.OutOfSampleValidation(5, 99999, 10, Engines.Serial())
                artifact = SDDPlab.Lab.validate(model, validation, study.inputs.files)

                mktempdir() do tmpdir
                    SDDPlab.Lab.save_validation(
                        artifact, tmpdir, SDDPlab.ParquetFormat(), study.inputs.files
                    )

                    # Check that statistics file was written
                    stats_file = joinpath(tmpdir, "validation_statistics.parquet")
                    @test isfile(stats_file)

                    # Check that at least one operation file was written
                    system_file = joinpath(tmpdir, "validation_operation_system.parquet")
                    @test isfile(system_file)
                end
            end
        end

        @testset "different-seeds-produce-different-scenarios" begin
            using HiGHS

            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)

            @suppress begin
                model = SDDPlab.build(study)
                SDDPlab.train(study, model)

                val1 = Engines.OutOfSampleValidation(5, 12345, 10, Engines.Serial())
                artifact1 = SDDPlab.Lab.validate(model, val1, study.inputs.files)

                val2 = Engines.OutOfSampleValidation(5, 99999, 10, Engines.Serial())
                artifact2 = SDDPlab.Lab.validate(model, val2, study.inputs.files)

                # Different seeds should produce different mean costs (with high probability)
                @test artifact1.statistics["mean_cost"] != artifact2.statistics["mean_cost"]
            end
        end
    end

    @testset "generate-saa-ar-different-seeds" begin
        import SDDPlab: Scenarios, StochasticProcess

        # Build a ScenariosData with an AutoRegressive stochastic process
        function _make_ar_dict_val(mean::Float64, std::Float64)
            return Dict{String,Any}(
                "kind" => "AutoRegressive",
                "params" => Dict{String,Any}(
                    "marginal_models" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "initial_values" => [mean],
                            "models" => [
                                Dict{String,Any}(
                                    "season" => 1,
                                    "coefficients" => [0.5],
                                    "scale_parameters" => [mean, std],
                                    "residual_variance" => 1.0,
                                ),
                            ],
                        ),
                    ],
                    "copulas" => [
                        Dict{String,Any}(
                            "season" => 1,
                            "kind" => "GaussianCopula",
                            "parameters" => [[1.0]],
                        ),
                    ],
                ),
            )
        end

        function _make_graph_dict_val(num_stages::Int)
            nodes = []
            for i in 1:num_stages
                push!(nodes, Dict{String,Any}(
                    "id" => i,
                    "stage" => i,
                    "start_datetime" => "2024-0$(i)-01",
                    "end_datetime" => "2024-0$(i + 1)-01",
                ))
            end
            edges = []
            for i in 1:(num_stages - 1)
                push!(edges, Dict{String,Any}(
                    "source" => i,
                    "target" => i + 1,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ))
            end
            return Dict{String,Any}(
                "params" => Dict{String,Any}("nodes" => nodes, "edges" => edges),
            )
        end

        function _make_load_dict_val(num_stages::Int)
            values = []
            for i in 1:num_stages
                push!(values, Dict{String,Any}(
                    "bus_id" => 1, "node_id" => i, "value" => 100.0
                ))
            end
            return Dict{String,Any}(
                "kind" => "DeterministicLoad",
                "params" => Dict{String,Any}("values" => values),
            )
        end

        @testset "ar-process-different-seeds" begin
            scenarios_d = Dict{String,Any}(
                "seed" => 42,
                "initial_season" => 1,
                "branchings" => 10,
                "graph" => _make_graph_dict_val(2),
                "inflow" => Dict{String,Any}(
                    "stochastic_process" => _make_ar_dict_val(50.0, 10.0),
                ),
                "load" => _make_load_dict_val(2),
            )
            e = CompositeException()
            scenarios = Scenarios.ScenariosData(scenarios_d, e)
            @test scenarios !== nothing
            @test length(e) == 0

            num_stages = 2
            branchings = 15

            saa1 = Engines.generate_saa(scenarios, num_stages, 12345, branchings)
            saa2 = Engines.generate_saa(scenarios, num_stages, 99999, branchings)

            # Both should return valid structures
            @test saa1 isa Dict{Int,Vector{Vector{Vector{Float64}}}}
            @test saa2 isa Dict{Int,Vector{Vector{Vector{Float64}}}}
            @test haskey(saa1, 1)
            @test haskey(saa2, 1)
            @test length(saa1[1]) == num_stages
            @test length(saa2[1]) == num_stages

            # Different seeds should produce different SAA realizations
            @test saa1[1] != saa2[1]

            # Same seed should produce same result (reproducibility)
            saa3 = Engines.generate_saa(scenarios, num_stages, 12345, branchings)
            @test saa1[1] == saa3[1]
        end

        @testset "markov-ar-process-different-seeds" begin
            # Build ScenariosData with Markov chain and 2 AR processes
            function _make_markov_chain_dict_val()
                return Dict{String,Any}(
                    "transition_matrices" => [
                        [[0.5, 0.5]],
                        [[0.8, 0.2], [0.3, 0.7]],
                    ],
                )
            end

            scenarios_d = Dict{String,Any}(
                "seed" => 42,
                "initial_season" => 1,
                "branchings" => 10,
                "graph" => _make_graph_dict_val(2),
                "markov_chain" => _make_markov_chain_dict_val(),
                "inflow" => Dict{String,Any}(
                    "stochastic_process" => Dict{String,Any}(
                        "1" => _make_ar_dict_val(40.0, 10.0),
                        "2" => _make_ar_dict_val(80.0, 20.0),
                    ),
                ),
                "load" => _make_load_dict_val(2),
            )
            e = CompositeException()
            scenarios = Scenarios.ScenariosData(scenarios_d, e)
            @test scenarios !== nothing
            @test length(e) == 0

            num_stages = 2
            branchings = 15

            saa1 = Engines.generate_saa(scenarios, num_stages, 11111, branchings)
            saa2 = Engines.generate_saa(scenarios, num_stages, 77777, branchings)

            # Both should have entries for 2 Markov states
            @test haskey(saa1, 1) && haskey(saa1, 2)
            @test haskey(saa2, 1) && haskey(saa2, 2)

            # Different seeds should produce different results for each Markov state
            @test saa1[1] != saa2[1]
            @test saa1[2] != saa2[2]
        end
    end

    @testset "validate-markov-model" begin
        using HiGHS
        import SDDPlab: Scenarios, Lab, System

        @testset "markov-policy-graph-validation" begin
            # Build ScenariosData with Markov chain and 2 AR processes
            function _make_ar_dict_markov(mean::Float64, std::Float64)
                return Dict{String,Any}(
                    "kind" => "AutoRegressive",
                    "params" => Dict{String,Any}(
                        "marginal_models" => [
                            Dict{String,Any}(
                                "id" => 1,
                                "initial_values" => [mean],
                                "models" => [
                                    Dict{String,Any}(
                                        "season" => 1,
                                        "coefficients" => [0.5],
                                        "scale_parameters" => [mean, std],
                                        "residual_variance" => 1.0,
                                    ),
                                ],
                            ),
                        ],
                        "copulas" => [
                            Dict{String,Any}(
                                "season" => 1,
                                "kind" => "GaussianCopula",
                                "parameters" => [[1.0]],
                            ),
                        ],
                    ),
                )
            end

            scenarios_d = Dict{String,Any}(
                "seed" => 42,
                "initial_season" => 1,
                "branchings" => 10,
                "graph" => Dict{String,Any}(
                    "params" => Dict{String,Any}(
                        "nodes" => [
                            Dict{String,Any}(
                                "id" => 1, "stage" => 1,
                                "start_datetime" => "2024-01-01",
                                "end_datetime" => "2024-02-01",
                            ),
                            Dict{String,Any}(
                                "id" => 2, "stage" => 2,
                                "start_datetime" => "2024-02-01",
                                "end_datetime" => "2024-03-01",
                            ),
                        ],
                        "edges" => [
                            Dict{String,Any}(
                                "source" => 1, "target" => 2,
                                "probability" => 1.0, "discount_rate" => 0.0,
                            ),
                        ],
                    ),
                ),
                "markov_chain" => Dict{String,Any}(
                    "transition_matrices" => [
                        [[0.5, 0.5]],
                        [[0.8, 0.2], [0.3, 0.7]],
                    ],
                ),
                "inflow" => Dict{String,Any}(
                    "stochastic_process" => Dict{String,Any}(
                        "1" => _make_ar_dict_markov(40.0, 10.0),
                        "2" => _make_ar_dict_markov(80.0, 20.0),
                    ),
                ),
                "load" => Dict{String,Any}(
                    "kind" => "DeterministicLoad",
                    "params" => Dict{String,Any}(
                        "values" => [
                            Dict{String,Any}(
                                "bus_id" => 1, "node_id" => 1, "value" => 50.0
                            ),
                            Dict{String,Any}(
                                "bus_id" => 1, "node_id" => 2, "value" => 50.0
                            ),
                        ],
                    ),
                ),
            )
            e_sc = CompositeException()
            scenarios = Scenarios.ScenariosData(scenarios_d, e_sc)
            @test scenarios !== nothing
            @test length(e_sc) == 0

            # Build minimal system
            system_d = convert(Dict{String,Any}, Dict(
                "buses" => Dict{String,Any}(
                    "entities" => [
                        Dict{String,Any}(
                            "id" => 1, "name" => "bus1", "deficit_cost" => 1000.0
                        ),
                    ],
                ),
                "lines" => Dict{String,Any}("entities" => Any[]),
                "thermals" => Dict{String,Any}("entities" => Any[]),
                "hydros" => Dict{String,Any}(
                    "entities" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "name" => "hydro1",
                            "bus_id" => 1,
                            "downstream_id" => 0,
                            "productivity" => 1.0,
                            "initial_storage" => 50.0,
                            "min_storage" => 0.0,
                            "max_storage" => 100.0,
                            "min_generation" => 0.0,
                            "max_generation" => 80.0,
                            "spillage_penalty" => 0.001,
                        ),
                    ],
                ),
            ))
            e_sys = CompositeException()
            system = SDDPlab.System.SystemData(system_d, e_sys)
            @test system !== nothing
            @test length(e_sys) == 0

            files = Lab.InputModule[scenarios, system]

            # Build engine with validation config
            convergence = Engines.Convergence(1, 3, [Engines.IterationLimit(3)])
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
                5, Engines.Serial(), Engines.DefaultSampling()
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

            @suppress begin
                model = Lab.build(engine, files)
                @test model isa Engines.SDDPModel
                @test model.policy_graph isa SDDP.PolicyGraph{Tuple{Int64,Int64}}

                Lab.train(model, policy_def)

                # Run out-of-sample validation with Markov tuple nodes
                validation = Engines.OutOfSampleValidation(5, 99999, 10, Engines.Serial())
                artifact = Lab.validate(model, validation, files)

                @test artifact isa Engines.SDDPValidationTaskArtifact
                @test length(artifact.simulations) == 5
                @test haskey(artifact.statistics, "mean_cost")
                @test haskey(artifact.statistics, "std_cost")
                @test haskey(artifact.statistics, "ci_lower_95")
                @test haskey(artifact.statistics, "ci_upper_95")
                @test haskey(artifact.statistics, "num_simulations")
                @test artifact.statistics["num_simulations"] == 5.0
            end
        end
    end

    @testset "study-api" begin
        @testset "validate-no-config-errors" begin
            e = CompositeException()
            d = deepcopy(ENGINE_DICT_WITHOUT_VALIDATION)
            Engines.__build_engine!(d, e)
            engine = d["engine"]::Engines.SDDPEngine

            @test Engines.get_validation_definition(engine) === nothing
        end

        @testset "validate-with-config-from-jsonc" begin
            using HiGHS

            # Manually create a study-like scenario with validation config
            e = CompositeException()
            study = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            # The 1dtoy example doesn't have validation, so validate should fail
            @test_throws ErrorException SDDPlab.validate(study, SDDPlab.build(study))
        end
    end
end
