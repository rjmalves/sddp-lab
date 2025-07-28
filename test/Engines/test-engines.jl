import SDDPlab: Engines

using Dates
using DataFrames
using JSON

CONVERGENCE_DICT = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 128,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "IterationLimit",
        "params" => Dict{String,Any}("num_iterations" => 128),
    ),
)

RISK_MEASURE_DICT = Dict{String,Any}(
    "kind" => "CVaR", "params" => Dict{String,Any}("alpha" => 0.2, "lambda" => 0.9)
)

PARALLEL_SCHEME_DICT = Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}())

POLICY_DICT = Dict{String,Any}(
    "convergence" => CONVERGENCE_DICT,
    "risk_measure" => RISK_MEASURE_DICT,
    "parallel_scheme" => PARALLEL_SCHEME_DICT,
)

SIMULATION_DICT = Dict{String,Any}(
    "num_simulated_series" => 100, "parallel_scheme" => PARALLEL_SCHEME_DICT
)

DICT = Dict{String,Any}(
    "engine" => Dict{String,Any}(
        "kind" => "SDDPEngine",
        "params" =>
            Dict{String,Any}("policy" => POLICY_DICT, "simulation" => SIMULATION_DICT),
    ),
)

@testset "engines-engine" begin
    @testset "engines-valid" begin
        d, e = __renew(DICT)
        Engines.__build_engine!(d, e)
        @test typeof(d["engine"]) === Engines.SDDPEngine
    end
end