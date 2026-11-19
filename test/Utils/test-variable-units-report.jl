import SDDPlab: Utils, Lab
using JuMP
using DataFrames

@testset "variable-units-report" begin
    @testset "bounded-variables" begin
        model = JuMP.Model()

        # Create variables mimicking SDDPlab model structure
        # STORED_VOLUME is Symbol("STORAGE") in Lab
        model[Lab.DEFICIT] = JuMP.@variable(model, [1:2], base_name = String(Lab.DEFICIT))
        JuMP.set_lower_bound.(model[Lab.DEFICIT], 0.0)
        JuMP.set_upper_bound.(model[Lab.DEFICIT], 25_000.0)

        model[Lab.THERMAL_GENERATION] = JuMP.@variable(
            model, [1:3], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound.(model[Lab.THERMAL_GENERATION], 0.0)
        JuMP.set_upper_bound.(model[Lab.THERMAL_GENERATION], 5_000.0)

        report = Utils.get_coefficient_magnitude_report(model)

        @test report isa DataFrame
        @test "variable" in names(report)
        @test "unit" in names(report)
        @test "actual_lower_bound" in names(report)
        @test "actual_upper_bound" in names(report)
        @test "expected_min_magnitude" in names(report)
        @test "expected_max_magnitude" in names(report)
        @test "magnitude_ratio" in names(report)

        # Should have rows for DEFICIT and THERMAL_GENERATION only
        # (other registered variables are not in the model)
        @test nrow(report) == 2

        # Check DEFICIT row
        deficit_row = filter(row -> row.variable == String(Lab.DEFICIT), report)
        @test nrow(deficit_row) == 1
        @test deficit_row[1, :unit] == "MW"
        @test deficit_row[1, :actual_lower_bound] == 0.0
        @test deficit_row[1, :actual_upper_bound] == 25_000.0
        @test deficit_row[1, :expected_min_magnitude] == 0.0
        @test deficit_row[1, :expected_max_magnitude] == 50_000.0
        @test deficit_row[1, :magnitude_ratio] == 25_000.0 / 50_000.0

        # Check THERMAL_GENERATION row
        thermal_row = filter(row -> row.variable == String(Lab.THERMAL_GENERATION), report)
        @test nrow(thermal_row) == 1
        @test thermal_row[1, :unit] == "MW"
        @test thermal_row[1, :actual_lower_bound] == 0.0
        @test thermal_row[1, :actual_upper_bound] == 5_000.0
        @test thermal_row[1, :magnitude_ratio] == 5_000.0 / 10_000.0
    end

    @testset "unbounded-variables" begin
        model = JuMP.Model()

        # INFLOW with no upper bound
        model[Lab.INFLOW] = JuMP.@variable(model, [1:2], base_name = String(Lab.INFLOW))
        # Only set lower bound, leave upper bound unbounded
        JuMP.set_lower_bound.(model[Lab.INFLOW], 0.0)

        report = Utils.get_coefficient_magnitude_report(model)

        @test nrow(report) == 1
        inflow_row = report[1, :]
        @test inflow_row.variable == String(Lab.INFLOW)
        @test inflow_row.actual_lower_bound == 0.0
        @test isnan(inflow_row.actual_upper_bound)
        @test isnan(inflow_row.magnitude_ratio)
    end

    @testset "fully-unbounded-variables" begin
        model = JuMP.Model()

        # LOAD with no bounds at all
        model[Lab.LOAD] = JuMP.@variable(model, [1:1], base_name = String(Lab.LOAD))

        report = Utils.get_coefficient_magnitude_report(model)

        @test nrow(report) == 1
        load_row = report[1, :]
        @test load_row.variable == String(Lab.LOAD)
        @test isnan(load_row.actual_lower_bound)
        @test isnan(load_row.actual_upper_bound)
        @test isnan(load_row.magnitude_ratio)
    end

    @testset "empty-model" begin
        model = JuMP.Model()
        report = Utils.get_coefficient_magnitude_report(model)

        @test report isa DataFrame
        @test nrow(report) == 0
        @test "variable" in names(report)
        @test "magnitude_ratio" in names(report)
    end

    @testset "mixed-bounded-and-unbounded" begin
        model = JuMP.Model()

        # SPILLAGE: lower bounded only
        model[Lab.SPILLAGE] = JuMP.@variable(model, [1:1], base_name = String(Lab.SPILLAGE))
        JuMP.set_lower_bound(model[Lab.SPILLAGE][1], 0.0)

        # DIRECT_EXCHANGE: fully bounded
        model[Lab.DIRECT_EXCHANGE] = JuMP.@variable(
            model, [1:1], base_name = String(Lab.DIRECT_EXCHANGE)
        )
        JuMP.set_lower_bound(model[Lab.DIRECT_EXCHANGE][1], 0.0)
        JuMP.set_upper_bound(model[Lab.DIRECT_EXCHANGE][1], 3_000.0)

        report = Utils.get_coefficient_magnitude_report(model)

        @test nrow(report) == 2

        spillage_row = filter(row -> row.variable == String(Lab.SPILLAGE), report)
        @test nrow(spillage_row) == 1
        @test spillage_row[1, :actual_lower_bound] == 0.0
        @test isnan(spillage_row[1, :actual_upper_bound])
        @test isnan(spillage_row[1, :magnitude_ratio])

        exchange_row = filter(row -> row.variable == String(Lab.DIRECT_EXCHANGE), report)
        @test nrow(exchange_row) == 1
        @test exchange_row[1, :actual_lower_bound] == 0.0
        @test exchange_row[1, :actual_upper_bound] == 3_000.0
        @test exchange_row[1, :magnitude_ratio] == 3_000.0 / 10_000.0
    end

    @testset "multiple-elements-aggregate-bounds" begin
        model = JuMP.Model()

        # THERMAL_GENERATION with different bounds per element
        model[Lab.THERMAL_GENERATION] = JuMP.@variable(
            model, [1:3], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound(model[Lab.THERMAL_GENERATION][1], 10.0)
        JuMP.set_upper_bound(model[Lab.THERMAL_GENERATION][1], 1_000.0)
        JuMP.set_lower_bound(model[Lab.THERMAL_GENERATION][2], 0.0)
        JuMP.set_upper_bound(model[Lab.THERMAL_GENERATION][2], 5_000.0)
        JuMP.set_lower_bound(model[Lab.THERMAL_GENERATION][3], 50.0)
        JuMP.set_upper_bound(model[Lab.THERMAL_GENERATION][3], 8_000.0)

        report = Utils.get_coefficient_magnitude_report(model)

        thermal_row = filter(row -> row.variable == String(Lab.THERMAL_GENERATION), report)
        @test nrow(thermal_row) == 1
        # Aggregate: min of lower bounds = 0.0, max of upper bounds = 8000.0
        @test thermal_row[1, :actual_lower_bound] == 0.0
        @test thermal_row[1, :actual_upper_bound] == 8_000.0
        @test thermal_row[1, :magnitude_ratio] == 8_000.0 / 10_000.0
    end
end
