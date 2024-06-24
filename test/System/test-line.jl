import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "SIN",
    "source_bus_id" => 1,
    "target_bus_id" => 2,
    "capacity" => 500.0,
    "exchange_penalty" => 0.0,
)

BUSES_DICT = [
    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
    Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
]
BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system" begin
    @testset "line-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Line(d, BUSES, e)) === System.Line
    end

    @testset "line-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        @test System.Line(d, BUSES, e) === nothing
    end
end