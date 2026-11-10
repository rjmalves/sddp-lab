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

# same topology as DICT but with an explicit id=0 root node wired to node 1
ROOT_DICT = Dict{String,Any}(
    "nodes" => vcat(
        Dict{String,Any}(
            "id" => 0,
            "stage" => 0,
            "start_datetime" => "2024-01-01",
            "end_datetime" => "2024-01-01",
        ),
        DICT["nodes"],
    ),
    "edges" => vcat(
        Dict{String,Any}(
            "source" => 0, "target" => 1, "probability" => 1.0, "discount_rate" => 0.0
        ),
        DICT["edges"],
    ),
)

@testset "scenarios-graph" begin
    @testset "graph-valid" begin
        d, e = __renew(DICT)
        graph = Scenarios.Graph(d, e)
        @test typeof(graph) === Scenarios.Graph
    end

    @testset "graph-synthetic-root" begin
        d, e = __renew(DICT)
        graph = Scenarios.Graph(d, e)

        # a root at id=0 is created, kept out of the decision nodes
        @test graph.root_node.id == 0
        @test Scenarios.get_root_node_id(graph) == 0
        @test length(graph.nodes) == 2
        @test all(n.id != 0 for n in graph.nodes)
        @test Scenarios.get_number_of_stages(graph) == 2

        # root is wired to the entry node (id=1) at probability 1.0
        @test any(
            e -> e.source[].id == 0 && e.target[].id == 1 && e.probability == 1.0,
            graph.edges,
        )

        # synthetic root has stage 0 and a zero-width interval at the earliest start
        @test graph.root_node.stage == 0
        @test graph.root_node.start_datetime == graph.root_node.end_datetime
        @test graph.root_node.start_datetime == minimum(n -> n.start_datetime, graph.nodes)
    end

    @testset "graph-explicit-root" begin
        d, e = __renew(ROOT_DICT)
        graph = Scenarios.Graph(d, e)

        # the id=0 node from the dict becomes the root and is excluded from nodes
        @test graph.root_node.id == 0
        @test Scenarios.get_root_node_id(graph) == 0
        @test length(graph.nodes) == 2
        @test all(n.id != 0 for n in graph.nodes)
        @test Scenarios.get_number_of_stages(graph) == 2

        # the dict-supplied root edge is preserved (not duplicated)
        @test count(e -> e.source[].id == 0, graph.edges) == 1
    end
end