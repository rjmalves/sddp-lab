import SDDPlab: Scenarios
import SDDPlab: Utils

using Dates
using DataFrames
using JSON

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
            "season" => 1, "name" => "GaussianCopula", "parameters" => [[1.0]]
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
    "initial_season" => 1, "branchings" => 1, "inflow" => INFLOW_DICT, "load" => LOAD_DICT
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