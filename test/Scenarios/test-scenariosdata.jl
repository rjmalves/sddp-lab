import SDDPlab: Scenarios
import SDDPlab: Utils

using Dates
using DataFrames
using JSON

GRAPH_DICT = Dict{String,Any}(
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

NAIVE_INFLOW_DICT = Dict{String,Any}(
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

INFLOW_DICT = Dict{String,Any}(
    "stochastic_process" =>
        Dict{String,Any}("kind" => "Naive", "params" => NAIVE_INFLOW_DICT),
)

LOAD_DICT = Dict{String,Any}(
    "kind" => "DeterministicLoad",
    "params" => Dict{String,Any}(
        "values" =>
            [Dict{String,Any}("bus_id" => 1, "stage_index" => 1, "value" => 100.0)],
    ),
)

DICT = Dict{String,Any}(
    "seed" => 42,
    "initial_season" => 1,
    "branchings" => 1,
    "graph" => GRAPH_DICT,
    "inflow" => INFLOW_DICT,
    "load" => LOAD_DICT,
)

@testset "scenarios-scenariosdata" begin
    @testset "scenariosdata-valid" begin
        d, e = __renew(DICT)
        u = Scenarios.ScenariosData(d, e)
        @test typeof(u) === Scenarios.ScenariosData
    end
    @testset "scenariosdata-valid-from-file" begin
        d, e = __renew(DICT)
        cd(example_data_dir)
        u = Scenarios.ScenariosData("scenarios.jsonc", e)
        @test typeof(u) === Scenarios.ScenariosData
    end
end