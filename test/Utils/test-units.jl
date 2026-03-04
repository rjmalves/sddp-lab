import SDDPlab: Utils, Lab

@testset "units" begin
    @testset "PhysicalUnit-construction" begin
        @testset "MW" begin
            @test Utils.MW.name == "megawatt"
            @test Utils.MW.symbol == "MW"
            @test Utils.MW.category == :power
        end

        @testset "MWh" begin
            @test Utils.MWh.name == "megawatt-hour"
            @test Utils.MWh.symbol == "MWh"
            @test Utils.MWh.category == :energy
        end

        @testset "HM3" begin
            @test Utils.HM3.name == "cubic hectometer"
            @test Utils.HM3.symbol == "hm3"
            @test Utils.HM3.category == :volume
        end

        @testset "M3_PER_S" begin
            @test Utils.M3_PER_S.name == "cubic meters per second"
            @test Utils.M3_PER_S.symbol == "m3/s"
            @test Utils.M3_PER_S.category == :flow
        end

        @testset "DOLLAR_PER_MWH" begin
            @test Utils.DOLLAR_PER_MWH.name == "dollars per megawatt-hour"
            @test Utils.DOLLAR_PER_MWH.symbol == "\$/MWh"
            @test Utils.DOLLAR_PER_MWH.category == :cost_rate
        end

        @testset "DOLLAR" begin
            @test Utils.DOLLAR.name == "dollars"
            @test Utils.DOLLAR.symbol == "\$"
            @test Utils.DOLLAR.category == :cost
        end

        @testset "HOURS" begin
            @test Utils.HOURS.name == "hours"
            @test Utils.HOURS.symbol == "h"
            @test Utils.HOURS.category == :time
        end

        @testset "DIMENSIONLESS" begin
            @test Utils.DIMENSIONLESS.name == "dimensionless"
            @test Utils.DIMENSIONLESS.symbol == "-"
            @test Utils.DIMENSIONLESS.category == :dimensionless
        end
    end

    @testset "VariableUnitInfo-construction" begin
        info = Utils.VariableUnitInfo(Lab.STORED_VOLUME, Utils.HM3, 0.0, 100_000.0)
        @test info.variable == Lab.STORED_VOLUME
        @test info.unit === Utils.HM3
        @test info.min_magnitude == 0.0
        @test info.max_magnitude == 100_000.0
    end

    @testset "get_variable_unit" begin
        @testset "registered-variable" begin
            info = Utils.get_variable_unit(Lab.STORED_VOLUME)
            @test info !== nothing
            @test info.unit === Utils.HM3
            @test info.min_magnitude == 0.0
            @test info.max_magnitude == 100_000.0
        end

        @testset "unregistered-variable" begin
            @test Utils.get_variable_unit(Symbol("NONEXISTENT")) === nothing
        end

        @testset "all-expected-variables-registered" begin
            expected_vars = [
                Lab.STORED_VOLUME,
                Lab.HYDRO_GENERATION,
                Lab.THERMAL_GENERATION,
                Lab.TURBINED_FLOW,
                Lab.SPILLAGE,
                Lab.INFLOW,
                Lab.DEFICIT,
                Lab.LOAD,
                Lab.DIRECT_EXCHANGE,
                Lab.REVERSE_EXCHANGE,
            ]
            for sym in expected_vars
                info = Utils.get_variable_unit(sym)
                @test info !== nothing
                @test info.variable == sym
            end
        end
    end

    @testset "VARIABLE_UNITS_REGISTRY-completeness" begin
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.STORED_VOLUME)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.HYDRO_GENERATION)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.THERMAL_GENERATION)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.DEFICIT)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.TURBINED_FLOW)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.SPILLAGE)
        @test haskey(Utils.VARIABLE_UNITS_REGISTRY, Lab.INFLOW)
    end

    @testset "UnitConversion" begin
        @testset "construction" begin
            conv = Utils.UnitConversion(Utils.M3_PER_S, Utils.HM3, 2.592)
            @test conv.source === Utils.M3_PER_S
            @test conv.target === Utils.HM3
            @test conv.factor == 2.592
        end

        @testset "m3s-to-hm3-lookup" begin
            key = (Utils.M3_PER_S, Utils.HM3)
            @test haskey(Utils.UNIT_CONVERSIONS, key)
            conv = Utils.UNIT_CONVERSIONS[key]
            @test conv.source === Utils.M3_PER_S
            @test conv.target === Utils.HM3
            @test conv.factor == 2.592
        end

        @testset "hm3-to-m3s-lookup" begin
            key = (Utils.HM3, Utils.M3_PER_S)
            @test haskey(Utils.UNIT_CONVERSIONS, key)
            conv = Utils.UNIT_CONVERSIONS[key]
            @test conv.factor ≈ 1.0 / 2.592
        end

        @testset "mw-to-mwh-lookup" begin
            key = (Utils.MW, Utils.MWh)
            @test haskey(Utils.UNIT_CONVERSIONS, key)
            conv = Utils.UNIT_CONVERSIONS[key]
            @test conv.factor == 1.0
        end

        @testset "roundtrip-conversion" begin
            fwd = Utils.UNIT_CONVERSIONS[(Utils.M3_PER_S, Utils.HM3)]
            rev = Utils.UNIT_CONVERSIONS[(Utils.HM3, Utils.M3_PER_S)]
            @test fwd.factor * rev.factor ≈ 1.0
        end
    end

    @testset "unit-categories" begin
        @test Utils.MW.category == :power
        @test Utils.MWh.category == :energy
        @test Utils.HM3.category == :volume
        @test Utils.M3_PER_S.category == :flow
        @test Utils.DOLLAR_PER_MWH.category == :cost_rate
        @test Utils.DOLLAR.category == :cost
        @test Utils.HOURS.category == :time
        @test Utils.DIMENSIONLESS.category == :dimensionless
    end
end
