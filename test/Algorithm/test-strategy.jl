import SDDPlab: Algorithm

using Dates

DICT::Dict{String,Any} = Dict(
    "policy_graph" =>
        Dict("kind" => "RegularPolicyGraph", "params" => Dict("discount_rate" => 1.00)),
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

@testset "algorithm-strategy" begin
    @testset "strategy-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.Strategy(d, e)) === Algorithm.Strategy
    end
end