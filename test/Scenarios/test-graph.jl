import SDDPlab: Scenarios

function __make_valid_graph_dict()
    return Dict{String,Any}(
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
    )
end

@testset "scenarios-graph" begin

    # --- Valid construction ---

    @testset "graph-valid" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test typeof(graph) === Scenarios.Graph
        @test length(graph.nodes) == 2
        @test length(graph.edges) == 1
    end

    @testset "graph-valid-from-file" begin
        e = CompositeException()
        cd(example_data_dir)
        graph = Scenarios.Graph("graph.jsonc", e)
        @test typeof(graph) === Scenarios.Graph
        @test length(graph.nodes) == 4
        @test length(graph.edges) == 3
    end

    # --- Missing keys ---

    @testset "graph-missing-nodes-key" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        delete!(d, "nodes")
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "graph-missing-edges-key" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        delete!(d, "edges")
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    # --- Node validation ---

    @testset "node-negative-id" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["id"] = -1
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "node-zero-id" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["id"] = 0
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "node-zero-stage" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["stage"] = 0
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "node-negative-stage" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["stage"] = -1
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "node-end-datetime-before-start" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["start_datetime"] = "2024-03-01"
        d["nodes"][1]["end_datetime"] = "2024-01-01"
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "node-end-datetime-equal-start" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][1]["start_datetime"] = "2024-01-01"
        d["nodes"][1]["end_datetime"] = "2024-01-01"
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    # --- Edge validation ---

    @testset "edge-negative-probability" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["edges"][1]["probability"] = -0.5
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "edge-probability-greater-than-one" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["edges"][1]["probability"] = 1.5
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "edge-negative-discount-rate" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["edges"][1]["discount_rate"] = -0.1
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "edge-nonexistent-source" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["edges"][1]["source"] = 99
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "edge-nonexistent-target" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["edges"][1]["target"] = 99
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    # --- Graph consistency ---

    @testset "graph-duplicate-node-ids" begin
        d = __make_valid_graph_dict()
        e = CompositeException()
        d["nodes"][2]["id"] = 1
        d["edges"][1]["target"] = 1
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    @testset "graph-multiple-root-nodes" begin
        d = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-01-01",
                    "end_datetime" => "2024-02-01",
                ),
                Dict{String,Any}(
                    "id" => 2,
                    "stage" => 1,
                    "start_datetime" => "2024-01-01",
                    "end_datetime" => "2024-02-01",
                ),
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-03-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 3,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end

    # --- Same-stage datetime consistency ---

    @testset "same-stage-consistent-datetimes" begin
        d = Dict{String,Any}(
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
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-03-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test typeof(graph) === Scenarios.Graph
        @test length(e) == 0
    end

    @testset "same-stage-inconsistent-start-datetime" begin
        d = Dict{String,Any}(
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
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-04-01",
                    "end_datetime" => "2024-05-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
        @test any(
            ex -> occursin("stage 2", ex.msg) && occursin("inconsistent datetimes", ex.msg),
            e.exceptions,
        )
    end

    @testset "same-stage-inconsistent-end-datetime" begin
        d = Dict{String,Any}(
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
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-04-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
        @test any(
            ex -> occursin("stage 2", ex.msg) && occursin("inconsistent datetimes", ex.msg),
            e.exceptions,
        )
    end

    @testset "multiple-stages-one-inconsistent" begin
        d = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-01-01",
                    "end_datetime" => "2024-02-01",
                ),
                Dict{String,Any}(
                    "id" => 2,
                    "stage" => 1,
                    "start_datetime" => "2024-01-01",
                    "end_datetime" => "2024-02-01",
                ),
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-03-01",
                ),
                Dict{String,Any}(
                    "id" => 4,
                    "stage" => 2,
                    "start_datetime" => "2024-05-01",
                    "end_datetime" => "2024-06-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 4,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 4,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
        @test any(
            ex -> occursin("stage 2", ex.msg) && occursin("inconsistent datetimes", ex.msg),
            e.exceptions,
        )
        @test !any(
            ex ->
                isa(ex, AssertionError) &&
                    occursin("stage 1", ex.msg) &&
                    occursin("inconsistent datetimes", ex.msg),
            e.exceptions,
        )
    end

    @testset "multiple-stages-both-inconsistent" begin
        d = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-01-01",
                    "end_datetime" => "2024-02-01",
                ),
                Dict{String,Any}(
                    "id" => 2,
                    "stage" => 1,
                    "start_datetime" => "2024-03-01",
                    "end_datetime" => "2024-04-01",
                ),
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-03-01",
                ),
                Dict{String,Any}(
                    "id" => 4,
                    "stage" => 2,
                    "start_datetime" => "2024-05-01",
                    "end_datetime" => "2024-06-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 4,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 3,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 4,
                    "probability" => 0.5,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
        datetime_errors = filter(
            ex -> isa(ex, AssertionError) && occursin("inconsistent datetimes", ex.msg),
            e.exceptions,
        )
        @test length(datetime_errors) >= 2
    end

    @testset "graph-probabilities-not-summing-to-one" begin
        d = Dict{String,Any}(
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
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 2,
                    "start_datetime" => "2024-02-01",
                    "end_datetime" => "2024-03-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 0.3,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 3,
                    "probability" => 0.3,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e = CompositeException()
        graph = Scenarios.Graph(d, e)
        @test graph === nothing
    end
end
