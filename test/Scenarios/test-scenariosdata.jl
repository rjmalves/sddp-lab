import SDDPlab: Scenarios
import SDDPlab: Utils
import SDDPlab: StochasticProcess

using Dates
using DataFrames
using JSON
using Random

function __make_scenariosdata_dict()
    graph_dict = Dict{String,Any}(
        Dict{String,Any}(
            "params" => Dict{String,Any}(
                "nodes" => [
                    Dict{String,Any}(
                        "id" => 1,
                        "stage" => 1,
                        "start_datetime" => "2024-01-01",
                        "end_datetime" => "2024-02-01",
                    ),
                    Dict{String,Any}(
                        "id" => 2,
                        "stage" => 2,
                        "start_datetime" => "2024-02-01",
                        "end_datetime" => "2024-03-01",
                    ),
                ],
                "edges" => [
                    Dict{String,Any}(
                        "source" => 1,
                        "target" => 2,
                        "probability" => 1.0,
                        "discount_rate" => 0.0,
                    ),
                ],
            ),
        ),
    )

    naive_inflow_dict = Dict{String,Any}(
        "marginal_models" => [
            Dict{String,Any}(
                "id" => 1,
                "distributions" => [
                    Dict{String,Any}(
                        "season" => 1, "kind" => "Normal", "parameters" => [70.0, 7.0]
                    ),
                ],
            ),
        ],
        "copulas" => [
            Dict{String,Any}(
                "season" => 1, "kind" => "GaussianCopula", "parameters" => [[1.0]]
            ),
        ],
    )

    inflow_dict = Dict{String,Any}(
        "stochastic_process" =>
            Dict{String,Any}("kind" => "Naive", "params" => naive_inflow_dict),
    )

    load_dict = Dict{String,Any}(
        "kind" => "DeterministicLoad",
        "params" => Dict{String,Any}(
            "values" =>
                [Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0)],
        ),
    )

    return Dict{String,Any}(
        "seed" => 42,
        "initial_season" => 1,
        "branchings" => 1,
        "graph" => graph_dict,
        "inflow" => inflow_dict,
        "load" => load_dict,
    )
end

@testset "scenarios-scenariosdata" begin
    @testset "scenariosdata-valid" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        u = Scenarios.ScenariosData(d, e)
        @test typeof(u) === Scenarios.ScenariosData
    end
    @testset "scenariosdata-valid-from-file" begin
        e = CompositeException()
        cd(example_data_dir)
        u = Scenarios.ScenariosData("scenarios.jsonc", e)
        @test typeof(u) === Scenarios.ScenariosData
    end

    # --- Negative tests: seed ---

    @testset "scenariosdata-seed-negative-is-valid" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        d["seed"] = -1
        u = Scenarios.ScenariosData(d, e)
        @test typeof(u) === Scenarios.ScenariosData
    end

    # --- Negative tests: branchings ---

    @testset "scenariosdata-invalid-branchings-zero" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        d["branchings"] = 0
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    @testset "scenariosdata-invalid-branchings-negative" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        d["branchings"] = -5
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    # --- Negative tests: initial_season ---

    @testset "scenariosdata-invalid-initial-season-zero" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        d["initial_season"] = 0
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    # --- Negative tests: missing keys ---

    @testset "scenariosdata-missing-inflow" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        delete!(d, "inflow")
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    @testset "scenariosdata-missing-load" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        delete!(d, "load")
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    @testset "scenariosdata-missing-graph" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        delete!(d, "graph")
        @test_throws KeyError Scenarios.ScenariosData(d, e)
    end

    # --- Consistency validation: load-graph node reference ---

    @testset "scenariosdata-load-node-id-nonexistent-in-graph" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        d["load"]["params"]["values"] = [
            Dict{String,Any}("bus_id" => 1, "node_id" => 99, "value" => 100.0),
        ]
        u = Scenarios.ScenariosData(d, e)
        @test u === nothing
        @test length(e) > 0
    end

    @testset "thread-safe-saa-generation" begin
        d = __make_scenariosdata_dict()
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios !== nothing
        process = Scenarios.get_stochastic_process(scenarios.inflow)
        initial_season = scenarios.initial_season
        branchings = scenarios.branchings
        num_stages = 2  # dict defines 2 nodes = 2 stages

        @testset "seed-passing-reproducibility" begin
            saa1 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings, 42
            )
            saa2 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings, 42
            )
            @test saa1 == saa2
        end

        @testset "no-seed-overload-reproducible-with-fixed-global-seed" begin
            # The no-seed overload uses the task-local (Xoshiro) RNG.  Seeding it
            # identically before each call must yield the same SAA.  This differs
            # from the MersenneTwister used by the seed-passing overload, so we
            # only verify internal consistency here, not cross-overload equality.
            Random.seed!(42)
            saa1 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings
            )
            Random.seed!(42)
            saa2 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings
            )
            @test saa1 == saa2
        end

        @testset "different-seeds-produce-different-saa" begin
            saa1 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings, 42
            )
            saa2 = StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings, 123
            )
            @test saa1 != saa2
        end

        @testset "global-rng-not-mutated-by-seed-passing-overload" begin
            Random.seed!(999)
            rng_state_before = copy(Random.default_rng())
            ref_value = rand(rng_state_before)

            Random.seed!(999)
            StochasticProcess.generate_saa(
                process, initial_season, num_stages, branchings, 42
            )
            observed_value = rand()

            @test observed_value == ref_value
        end

        @testset "set-seed-emits-deprecation-warning" begin
            @test_logs (:warn, r"set_seed! mutates the global RNG") Scenarios.set_seed!(scenarios)
        end
    end
end
