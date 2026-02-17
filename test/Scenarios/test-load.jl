import SDDPlab: Scenarios

DETERMINISTIC_LOAD_DICT = Dict{String,Any}(
    "values" => [Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0)]
)

MULTI_VALUE_LOAD_DICT = Dict{String,Any}(
    "values" => [
        Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0),
        Dict{String,Any}("bus_id" => 1, "node_id" => 2, "value" => 150.0),
        Dict{String,Any}("bus_id" => 2, "node_id" => 1, "value" => 200.0),
        Dict{String,Any}("bus_id" => 2, "node_id" => 2, "value" => 250.0),
    ],
)

@testset "scenarios-load" begin

    # --- Valid construction ---

    @testset "deterministic-load-valid" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        load = Scenarios.DeterministicLoad(d, e)
        @test typeof(load) === Scenarios.DeterministicLoad
    end

    @testset "deterministic-load-valid-multi-value" begin
        d, e = __renew(MULTI_VALUE_LOAD_DICT)
        load = Scenarios.DeterministicLoad(d, e)
        @test typeof(load) === Scenarios.DeterministicLoad
        @test length(load.values) == 4
    end

    # --- Missing/invalid keys ---

    @testset "deterministic-load-invalid-key" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        pop!(d, "values")
        load = Scenarios.DeterministicLoad(d, e)
        @test load === nothing
    end

    @testset "deterministic-load-invalid-type" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        d["values"] = nothing
        load = Scenarios.DeterministicLoad(d, e)
        @test load === nothing
    end

    # --- DeterministicLoadValue tests ---

    @testset "deterministic-load-value-valid" begin
        d = Dict{String,Any}("bus_id" => 1, "node_id" => 2, "value" => 100.0)
        e = CompositeException()
        v = Scenarios.DeterministicLoadValue(d, e)
        @test typeof(v) === Scenarios.DeterministicLoadValue
        @test v.bus_id == 1
        @test v.node_id == 2
        @test v.value == 100.0
    end

    @testset "deterministic-load-value-invalid-bus-id-zero" begin
        d = Dict{String,Any}("bus_id" => 0, "node_id" => 1, "value" => 100.0)
        e = CompositeException()
        v = Scenarios.DeterministicLoadValue(d, e)
        @test v === nothing
        @test length(e) > 0
    end

    @testset "deterministic-load-value-invalid-node-id-zero" begin
        d = Dict{String,Any}("bus_id" => 1, "node_id" => 0, "value" => 100.0)
        e = CompositeException()
        v = Scenarios.DeterministicLoadValue(d, e)
        @test v === nothing
        @test length(e) > 0
    end

    @testset "deterministic-load-value-negative-value-allowed" begin
        # Negative load values should be allowed (e.g., generation at bus)
        d = Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => -50.0)
        e = CompositeException()
        v = Scenarios.DeterministicLoadValue(d, e)
        @test typeof(v) === Scenarios.DeterministicLoadValue
        @test v.value == -50.0
    end

    # --- Duplicate bus/node pair ---

    @testset "deterministic-load-duplicate-bus-node-pair" begin
        d = Dict{String,Any}(
            "values" => [
                Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0),
                Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 200.0),
            ],
        )
        e = CompositeException()
        load = Scenarios.DeterministicLoad(d, e)
        @test load === nothing
        @test length(e) > 0
    end

    # --- Load lookup function ---

    @testset "deterministic-load-lookup-existing" begin
        d, e = __renew(MULTI_VALUE_LOAD_DICT)
        load = Scenarios.DeterministicLoad(d, e)
        @test load !== nothing
        @test Scenarios.__get_load(1, 1, load) == 100.0
        @test Scenarios.__get_load(1, 2, load) == 150.0
        @test Scenarios.__get_load(2, 1, load) == 200.0
        @test Scenarios.__get_load(2, 2, load) == 250.0
    end

    @testset "deterministic-load-lookup-missing-defaults-to-zero" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        load = Scenarios.DeterministicLoad(d, e)
        @test load !== nothing
        result = @test_logs (:warn,) Scenarios.__get_load(99, 99, load)
        @test result == 0.0
    end

    # --- Load-graph consistency validation ---

    @testset "deterministic-load-node-id-nonexistent-in-graph" begin
        graph_d = Dict{String,Any}(
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
        ge = CompositeException()
        graph = Scenarios.Graph(graph_d, ge)
        @test graph !== nothing

        load_values = [Scenarios.DeterministicLoadValue(1, 99, 100.0)]
        load = Scenarios.DeterministicLoad(load_values)

        e = CompositeException()
        valid = Scenarios.__validate_deterministic_load_node_references!(load, graph, e)
        @test valid == false
        @test length(e) > 0
    end
end