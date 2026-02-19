import SDDPlab: System

HYDRO1_DICT = Dict{String,Any}(
    "id" => 1,
    "downstream_id" => 0,
    "name" => "UHE1",
    "bus_id" => 1,
    "productivity" => 1.0,
    "initial_storage" => 50.0,
    "min_storage" => 0.0,
    "max_storage" => 100.0,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "spillage_penalty" => 0.01,
)

HYDRO2_DICT = Dict{String,Any}(
    "id" => 2,
    "downstream_id" => 0,
    "name" => "UHE2",
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

HYDROS_DICT = Dict{String,Any}(
    "entities" => [deepcopy(HYDRO1_DICT), deepcopy(HYDRO2_DICT)],
)
HYDROS = System.Hydros(HYDROS_DICT, BUSES, CompositeException())

DICT = Dict{String,Any}(
    "id" => 1,
    "name" => "SANTA_CECILIA",
    "bus_id" => 1,
    "source_hydro_id" => 1,
    "destination_hydro_id" => 2,
    "consumption_mw_per_m3s" => 0.85,
    "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 150.0),
)

@testset "system-pumpingstation" begin
    @testset "pumpingstation-valid" begin
        d, e = __renew(DICT)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test typeof(ps) === System.PumpingStation
        @test ps.source_hydro_id == 1
        @test ps.destination_hydro_id == 2
        @test ps.consumption_mw_per_m3s == 0.85
        @test ps.min_m3s == 0.0
        @test ps.max_m3s == 150.0
    end

    @testset "pumpingstation-invalid-bus-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 99)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
    end

    @testset "pumpingstation-invalid-source-hydro-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "source_hydro_id", 99)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-invalid-destination-hydro-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "destination_hydro_id", 99)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-same-source-destination" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "destination_hydro_id", 1)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-missing-flow" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "flow")
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-min-greater-than-max-flow" begin
        d, e = __renew(DICT)
        d["flow"] = Dict{String,Any}("min_m3s" => 200.0, "max_m3s" => 100.0)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-negative-consumption" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "consumption_mw_per_m3s", -0.5)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test ps === nothing
        @test length(e) > 0
    end

    @testset "pumpingstation-zero-flow-valid" begin
        d, e = __renew(DICT)
        d["flow"] = Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 0.0)
        ps = System.PumpingStation(d, BUSES, HYDROS, e)
        @test typeof(ps) === System.PumpingStation
    end

    @testset "pumpingstations-unique-ids" begin
        d1 = Dict{String,Any}(
            "id" => 1, "name" => "PUMP_A", "bus_id" => 1,
            "source_hydro_id" => 1, "destination_hydro_id" => 2,
            "consumption_mw_per_m3s" => 0.85,
            "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 150.0),
        )
        d2 = Dict{String,Any}(
            "id" => 1, "name" => "PUMP_B", "bus_id" => 2,
            "source_hydro_id" => 2, "destination_hydro_id" => 1,
            "consumption_mw_per_m3s" => 0.90,
            "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 100.0),
        )
        ps_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        pss = System.PumpingStations(ps_dict, BUSES, HYDROS, e)
        @test pss === nothing
    end

    @testset "pumpingstations-unique-names" begin
        d1 = Dict{String,Any}(
            "id" => 1, "name" => "PUMP_A", "bus_id" => 1,
            "source_hydro_id" => 1, "destination_hydro_id" => 2,
            "consumption_mw_per_m3s" => 0.85,
            "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 150.0),
        )
        d2 = Dict{String,Any}(
            "id" => 2, "name" => "PUMP_A", "bus_id" => 2,
            "source_hydro_id" => 2, "destination_hydro_id" => 1,
            "consumption_mw_per_m3s" => 0.90,
            "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 100.0),
        )
        ps_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        pss = System.PumpingStations(ps_dict, BUSES, HYDROS, e)
        @test pss === nothing
    end

    @testset "systemdata-without-pumpingstations" begin
        d = Dict{String,Any}(
            "buses" => Dict{String,Any}(
                "entities" => [
                    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
                ],
            ),
            "lines" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "hydros" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "thermals" => Dict{String,Any}("entities" => Dict{String,Any}[]),
        )
        e = CompositeException()
        s = System.SystemData(d, e)
        @test typeof(s) === System.SystemData
        @test length(System.get_pumpingstations(s)) == 0
    end

    @testset "systemdata-with-pumpingstations" begin
        d = Dict{String,Any}(
            "buses" => Dict{String,Any}(
                "entities" => [
                    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
                ],
            ),
            "lines" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "hydros" => Dict{String,Any}(
                "entities" => [
                    Dict{String,Any}(
                        "id" => 1, "downstream_id" => 0, "name" => "UHE1", "bus_id" => 1,
                        "productivity" => 1.0, "initial_storage" => 50.0,
                        "min_storage" => 0.0, "max_storage" => 100.0,
                        "min_generation" => 0.0, "max_generation" => 300.0,
                        "spillage_penalty" => 0.01,
                    ),
                    Dict{String,Any}(
                        "id" => 2, "downstream_id" => 0, "name" => "UHE2", "bus_id" => 1,
                        "productivity" => 1.0, "initial_storage" => 50.0,
                        "min_storage" => 0.0, "max_storage" => 100.0,
                        "min_generation" => 0.0, "max_generation" => 300.0,
                        "spillage_penalty" => 0.01,
                    ),
                ],
            ),
            "thermals" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "pumpingstations" => Dict{String,Any}(
                "entities" => [
                    Dict{String,Any}(
                        "id" => 1, "name" => "PUMP_A", "bus_id" => 1,
                        "source_hydro_id" => 1, "destination_hydro_id" => 2,
                        "consumption_mw_per_m3s" => 0.85,
                        "flow" => Dict{String,Any}("min_m3s" => 0.0, "max_m3s" => 150.0),
                    ),
                ],
            ),
        )
        e = CompositeException()
        s = System.SystemData(d, e)
        @test typeof(s) === System.SystemData
        @test length(System.get_pumpingstations(s)) == 1
        @test System.get_pumpingstations_entities(s)[1].source_hydro_id == 1
    end
end
