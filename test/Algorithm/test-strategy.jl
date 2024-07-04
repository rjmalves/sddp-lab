import SDDPlab: Algorithm
import SDDPlab: Utils

using Dates
using DataFrames
using JSON

DICT = Dict{String,Any}(
    "scenario_graph" =>
        Dict("kind" => "RegularScenarioGraph", "params" => Dict("discount_rate" => 1.00)),
    "horizon" => Dict(
        "kind" => "ExplicitHorizon",
        "params" => Dict(
            "file" => "stages.csv",
            "stages" => [
                Dict(
                    "index" => 1,
                    "start_date" => DateTime(2020, 1, 1),
                    "end_date" => DateTime(2020, 2, 1),
                ),
            ],
        ),
    ),
    "risk_measure" => Dict("kind" => "Expectation", "params" => Dict()),
)

@testset "algorithm-strategy" begin
    @testset "strategy-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.Strategy(d, e)) === Algorithm.Strategy
    end
    @testset "strategy-valid-from-file" begin
        d, e = __renew(DICT)

        cd(example_data_dir)
        @test typeof(Algorithm.Strategy("algorithm.jsonc", e)) === Algorithm.Strategy
    end
end