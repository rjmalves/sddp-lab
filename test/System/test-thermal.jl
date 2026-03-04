import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "UTE1",
    "bus_id" => 1,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "cost" => 100.0,
)

BUSES_DICT = Dict{String,Any}(
    "entities" => [
        Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
        Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
    ],
)

BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system-thermal" begin
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

    # --- Schema boundary tests ---

    @testset "thermal-boundary-id-zero-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        thermal = System.Thermal(d, BUSES, e)
        @test thermal === nothing
        @test length(e) > 0
    end

    @testset "thermal-boundary-id-one-passes" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 1)
        thermal = System.Thermal(d, BUSES, e)
        @test typeof(thermal) === System.Thermal
    end

    @testset "thermal-invalid-negative-cost" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "cost", -10.0)
        thermal = System.Thermal(d, BUSES, e)
        @test thermal === nothing
        @test length(e) > 0
    end

    @testset "thermal-invalid-min-greater-than-max-generation" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_generation", 500.0)
        d = __modif_key(d, "max_generation", 100.0)
        thermal = System.Thermal(d, BUSES, e)
        @test thermal === nothing
        @test length(e) > 0
    end

    @testset "thermal-zero-generation-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_generation", 0.0)
        d = __modif_key(d, "max_generation", 0.0)
        thermal = System.Thermal(d, BUSES, e)
        @test typeof(thermal) === System.Thermal
    end
end
