import SDDPlab: System

DICT = Dict{String,Any}(
    "id" => 1,
    "name" => "ITAIPU_BR",
    "bus_id" => 1,
    "type" => "import",
    "price_per_mwh" => 50.0,
    "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 6000.0),
)

BUSES_DICT = Dict{String,Any}(
    "entities" => [
        Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
        Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
    ],
)

BUSES = System.Buses(BUSES_DICT, CompositeException())

@testset "system-energycontract" begin
    @testset "energycontract-valid-import" begin
        d, e = __renew(DICT)
        ec = System.EnergyContract(d, BUSES, e)
        @test typeof(ec) === System.EnergyContract
        @test ec.contract_type == "import"
        @test ec.price_per_mwh == 50.0
        @test ec.min_mw == 0.0
        @test ec.max_mw == 6000.0
    end

    @testset "energycontract-valid-export" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "type", "export")
        d = __modif_key(d, "price_per_mwh", -30.0)
        ec = System.EnergyContract(d, BUSES, e)
        @test typeof(ec) === System.EnergyContract
        @test ec.contract_type == "export"
    end

    @testset "energycontract-invalid-type" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "type", "bilateral")
        ec = System.EnergyContract(d, BUSES, e)
        @test ec === nothing
        @test length(e) > 0
    end

    @testset "energycontract-invalid-bus-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "bus_id", 99)
        ec = System.EnergyContract(d, BUSES, e)
        @test ec === nothing
    end

    @testset "energycontract-missing-limits" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "limits")
        ec = System.EnergyContract(d, BUSES, e)
        @test ec === nothing
        @test length(e) > 0
    end

    @testset "energycontract-min-greater-than-max" begin
        d, e = __renew(DICT)
        d["limits"] = Dict{String,Any}("min_mw" => 100.0, "max_mw" => 50.0)
        ec = System.EnergyContract(d, BUSES, e)
        @test ec === nothing
        @test length(e) > 0
    end

    @testset "energycontract-negative-price-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "type", "export")
        d = __modif_key(d, "price_per_mwh", -25.0)
        ec = System.EnergyContract(d, BUSES, e)
        @test typeof(ec) === System.EnergyContract
        @test ec.price_per_mwh == -25.0
    end

    @testset "energycontract-zero-bounds-valid" begin
        d, e = __renew(DICT)
        d["limits"] = Dict{String,Any}("min_mw" => 0.0, "max_mw" => 0.0)
        ec = System.EnergyContract(d, BUSES, e)
        @test typeof(ec) === System.EnergyContract
    end

    @testset "energycontracts-unique-ids" begin
        d1 = Dict{String,Any}(
            "id" => 1,
            "name" => "CONTRACT_A",
            "bus_id" => 1,
            "type" => "import",
            "price_per_mwh" => 50.0,
            "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 1000.0),
        )
        d2 = Dict{String,Any}(
            "id" => 1,
            "name" => "CONTRACT_B",
            "bus_id" => 2,
            "type" => "export",
            "price_per_mwh" => -30.0,
            "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 500.0),
        )
        ecs_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        ecs = System.EnergyContracts(ecs_dict, BUSES, e)
        @test ecs === nothing
    end

    @testset "energycontracts-unique-names" begin
        d1 = Dict{String,Any}(
            "id" => 1,
            "name" => "CONTRACT_A",
            "bus_id" => 1,
            "type" => "import",
            "price_per_mwh" => 50.0,
            "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 1000.0),
        )
        d2 = Dict{String,Any}(
            "id" => 2,
            "name" => "CONTRACT_A",
            "bus_id" => 2,
            "type" => "export",
            "price_per_mwh" => -30.0,
            "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 500.0),
        )
        ecs_dict = Dict{String,Any}("entities" => [d1, d2])
        e = CompositeException()
        ecs = System.EnergyContracts(ecs_dict, BUSES, e)
        @test ecs === nothing
    end

    @testset "systemdata-without-energycontracts" begin
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
        @test length(System.get_energycontracts(s)) == 0
    end

    @testset "systemdata-with-energycontracts" begin
        d = Dict{String,Any}(
            "buses" => Dict{String,Any}(
                "entities" => [
                    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
                ],
            ),
            "lines" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "hydros" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "thermals" => Dict{String,Any}("entities" => Dict{String,Any}[]),
            "energycontracts" => Dict{String,Any}(
                "entities" => [
                    Dict{String,Any}(
                        "id" => 1,
                        "name" => "CONTRACT_A",
                        "bus_id" => 1,
                        "type" => "import",
                        "price_per_mwh" => 50.0,
                        "limits" => Dict{String,Any}("min_mw" => 0.0, "max_mw" => 1000.0),
                    ),
                ],
            ),
        )
        e = CompositeException()
        s = System.SystemData(d, e)
        @test typeof(s) === System.SystemData
        @test length(System.get_energycontracts(s)) == 1
        @test System.get_energycontracts_entities(s)[1].contract_type == "import"
    end
end
