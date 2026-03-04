import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "SIN",
    "source_bus_id" => 1,
    "target_bus_id" => 2,
    "capacity" => 500.0,
    "exchange_penalty" => 0.0,
)

BUSES_DICT = Dict{String,Any}(
    "entities" => [
        Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
        Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
    ],
)

BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system-line" begin
    @testset "line-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Line(d, BUSES, e)) === System.Line
    end

    @testset "line-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        @test System.Line(d, BUSES, e) === nothing
    end

    @testset "line-nonexistent-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.Line(d, BUSES, e) === nothing
    end

    # --- Schema boundary tests ---

    @testset "line-boundary-id-one-passes" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 1)
        line = System.Line(d, BUSES, e)
        @test typeof(line) === System.Line
    end

    @testset "line-boundary-id-negative-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", -1)
        line = System.Line(d, BUSES, e)
        @test line === nothing
        @test length(e) > 0
    end

    @testset "line-invalid-source-bus-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "source_bus_id", 99)
        line = System.Line(d, BUSES, e)
        @test line === nothing
        @test length(e) > 0
    end

    @testset "line-invalid-target-bus-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "target_bus_id", 99)
        line = System.Line(d, BUSES, e)
        @test line === nothing
        @test length(e) > 0
    end

    @testset "line-missing-capacity" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "capacity")
        line = System.Line(d, BUSES, e)
        @test line === nothing
        @test length(e) > 0
    end
end
