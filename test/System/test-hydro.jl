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

BUSES_DICT = Dict{String,Any}(
    "entities" => [
        Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
        Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
    ],
)

BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system-hydro" begin
    @testset "hydro-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Hydro(d, BUSES, e)) === System.Hydro
    end

    @testset "hydro-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 3)
        @test System.Hydro(d, BUSES, e) === nothing
    end

    @testset "hydro-nonexistent-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.Hydro(d, BUSES, e) === nothing
    end

    # --- Schema boundary tests ---

    @testset "hydro-boundary-id-zero-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    @testset "hydro-boundary-id-one-passes" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 1)
        hydro = System.Hydro(d, BUSES, e)
        @test typeof(hydro) === System.Hydro
    end

    @testset "hydro-invalid-negative-productivity" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "productivity", -1.0)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    @testset "hydro-invalid-initial-storage-out-of-bounds" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "initial_storage", 200.0)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    @testset "hydro-invalid-min-greater-than-max-storage" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_storage", 200.0)
        d = __modif_key(d, "max_storage", 50.0)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    @testset "hydro-invalid-min-greater-than-max-generation" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_generation", 500.0)
        d = __modif_key(d, "max_generation", 100.0)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    @testset "hydro-invalid-negative-downstream-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "downstream_id", -1)
        hydro = System.Hydro(d, BUSES, e)
        @test hydro === nothing
        @test length(e) > 0
    end

    # TODO - testar downstream_id/grafo
end