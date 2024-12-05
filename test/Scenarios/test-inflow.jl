import SDDPlab: Scenarios
import SDDPlab: StochasticProcess

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

@testset "scenarios-inflow" begin
    @testset "inflow-valid" begin
        d, e = __renew(INFLOW_DICT)
        inflow = Scenarios.InflowScenarios(d, e)
        @test typeof(inflow) === Scenarios.InflowScenarios
    end

    @testset "inflow-invalid-key" begin
        d, e = __renew(INFLOW_DICT)
        pop!(d, "stochastic_process")
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow === nothing
    end

    @testset "inflow-invalid-type" begin
        d, e = __renew(INFLOW_DICT)
        d["stochastic_process"] = nothing
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow === nothing
    end
end