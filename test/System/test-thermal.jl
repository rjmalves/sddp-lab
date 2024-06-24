import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "UTE1",
    "bus_id" => 1,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "cost" => 100.0,
)

BUSES_DICT = [
    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
    Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
]
BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system" begin
    @testset "thermal-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Thermal(d, BUSES, e)) === System.Thermal
    end

    @testset "thermal-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 3)
        @test System.Thermal(d, BUSES, e) === nothing
    end

    @testset "thermal-nonexistent-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.Thermal(d, BUSES, e) === nothing
    end
end