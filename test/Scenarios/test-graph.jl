import SDDPlab: Scenarios

DICT = Dict{String,Any}(
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
            "source" => 1, "target" => 2, "probability" => 1.0, "discount_rate" => 0.0
        ),
    ],
)

@testset "scenarios-graph" begin
    @testset "graph-valid" begin
        d, e = __renew(DICT)
        graph = Scenarios.Graph(d, e)
        @test typeof(graph) === Scenarios.Graph
    end
end