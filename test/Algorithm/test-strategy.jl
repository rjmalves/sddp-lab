import SDDPlab: Algorithm
import SDDPlab: Utils

using Dates
using DataFrames
using JSON

DICT::Dict{String,Any} = Dict(
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
    "convergence" => Dict(
        "min_iterations" => 10,
        "max_iterations" => 100,
        "stopping_criteria" => Dict(
            "kind" => "LowerBoundStability",
            "params" => Dict("threshold" => 0.05, "num_iterations" => 5),
        ),
    ),
)

DF = DataFrame(;
    index = [1, 2],
    start_date = [DateTime(2020, 1, 1), DateTime(2020, 2, 1)],
    end_date = [DateTime(2020, 2, 1), DateTime(2020, 3, 1)],
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