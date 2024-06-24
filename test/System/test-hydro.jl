import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "UHE1",
    "downstream_id" => 0,
    "bus_id" => 1,
    "productivity" => 1.0,
    "initial_storage" => 50.0,
    "min_storage" => 0.0,
    "max_storage" => 100.0,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "spillage_penalty" => 0.01,
)

BUSES_DICT = [
    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
    Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
]
BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system" begin
    @testset "hydro-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Hydro(d, BUSES, e)) === System.Hydro
    end

    @testset "hydro-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 3)
        @test System.Hydro(d, BUSES, e) === nothing
    end

    @testset "thermal-nonexistent-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.Thermal(d, BUSES, e) === nothing
    end

    # TODO - testar downstream_id/grafo
end