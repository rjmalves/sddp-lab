import SDDPlab: System

DICT = Dict(
    "id" => 1,
    "name" => "WIND_FARM_NE",
    "bus_id" => 1,
    "max_generation" => 500.0,
    "curtailment_cost" => 0.005,
)

BUSES_DICT = Dict{String,Any}(
    "entities" => [
        Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
        Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
    ],
)

BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system-noncontrollable" begin
    @testset "noncontrollable-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.NonControllable(d, BUSES, e)) === System.NonControllable
    end

    @testset "noncontrollable-invalid-bus-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 3)
        @test System.NonControllable(d, BUSES, e) === nothing
    end

    @testset "noncontrollable-missing-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.NonControllable(d, BUSES, e) === nothing
    end

    @testset "noncontrollable-negative-max-generation" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_generation", -100.0)
        nc = System.NonControllable(d, BUSES, e)
        @test nc === nothing
        @test length(e) > 0
    end

    @testset "noncontrollable-negative-curtailment-cost" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "curtailment_cost", -0.01)
        nc = System.NonControllable(d, BUSES, e)
        @test nc === nothing
        @test length(e) > 0
    end

    @testset "noncontrollable-zero-max-generation" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_generation", 0.0)
        nc = System.NonControllable(d, BUSES, e)
        @test typeof(nc) === System.NonControllable
    end

    @testset "noncontrollable-boundary-id-zero-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        nc = System.NonControllable(d, BUSES, e)
        @test nc === nothing
        @test length(e) > 0
    end

    @testset "noncontrollable-boundary-id-one-passes" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 1)
        nc = System.NonControllable(d, BUSES, e)
        @test typeof(nc) === System.NonControllable
    end

    @testset "noncontrollables-unique-ids" begin
        d1 = Dict{String,Any}(
            "id" => 1,
            "name" => "WIND_FARM_NE",
            "bus_id" => 1,
            "max_generation" => 500.0,
            "curtailment_cost" => 0.005,
        )
        d2 = Dict{String,Any}(
            "id" => 1,
            "name" => "SOLAR_FARM_SE",
            "bus_id" => 2,
            "max_generation" => 300.0,
            "curtailment_cost" => 0.003,
        )
        ncs_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        ncs = System.NonControllables(ncs_dict, BUSES, e)
        @test ncs === nothing
    end

    @testset "noncontrollables-unique-names" begin
        d1 = Dict{String,Any}(
            "id" => 1,
            "name" => "WIND_FARM_NE",
            "bus_id" => 1,
            "max_generation" => 500.0,
            "curtailment_cost" => 0.005,
        )
        d2 = Dict{String,Any}(
            "id" => 2,
            "name" => "WIND_FARM_NE",
            "bus_id" => 2,
            "max_generation" => 300.0,
            "curtailment_cost" => 0.003,
        )
        ncs_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        ncs = System.NonControllables(ncs_dict, BUSES, e)
        @test ncs === nothing
    end
end
