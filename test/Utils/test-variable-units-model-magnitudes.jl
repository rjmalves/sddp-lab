import SDDPlab: Utils, Lab
using JuMP
using SDDP: SDDP
using HiGHS: HiGHS
using DataFrames
using Test
using Logging

@testset "variable-units-model-magnitudes" begin
    @testset "model-derived-magnitudes-bounded" begin
        # Build a simple SDDP model with known bounds for THERMAL_GENERATION and DEFICIT
        model = SDDP.LinearPolicyGraph(;
            stages = 3, sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        ) do sp, t
            # THERMAL_GENERATION with known bounds [0, 200]
            sp[Lab.THERMAL_GENERATION] = JuMP.@variable(
                sp, [1:2], base_name = String(Lab.THERMAL_GENERATION)
            )
            JuMP.set_lower_bound.(sp[Lab.THERMAL_GENERATION], 0.0)
            JuMP.set_upper_bound(sp[Lab.THERMAL_GENERATION][1], 100.0)
            JuMP.set_upper_bound(sp[Lab.THERMAL_GENERATION][2], 200.0)

            # DEFICIT with bounds [0, 500]
            sp[Lab.DEFICIT] = JuMP.@variable(sp, [1:1], base_name = String(Lab.DEFICIT))
            JuMP.set_lower_bound(sp[Lab.DEFICIT][1], 0.0)
            JuMP.set_upper_bound(sp[Lab.DEFICIT][1], 500.0)

            SDDP.@stageobjective(
                sp, sum(sp[Lab.THERMAL_GENERATION]) + 1000.0 * sum(sp[Lab.DEFICIT])
            )
            return nothing
        end

        mags = Utils.compute_model_magnitudes(model)

        # THERMAL_GENERATION should use model-derived max_magnitude = 200.0, not hardcoded 10_000.0
        @test haskey(mags, Lab.THERMAL_GENERATION)
        @test mags[Lab.THERMAL_GENERATION].max_magnitude == 200.0
        @test mags[Lab.THERMAL_GENERATION].min_magnitude == 0.0
        @test mags[Lab.THERMAL_GENERATION].unit == Utils.MW

        # DEFICIT should use model-derived max_magnitude = 500.0, not hardcoded 50_000.0
        @test haskey(mags, Lab.DEFICIT)
        @test mags[Lab.DEFICIT].max_magnitude == 500.0
        @test mags[Lab.DEFICIT].min_magnitude == 0.0
    end

    @testset "model-derived-magnitudes-unbounded-fallback" begin
        # Build a model where DEFICIT has only a lower bound (no upper bound)
        model = SDDP.LinearPolicyGraph(;
            stages = 2, sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        ) do sp, t
            sp[Lab.DEFICIT] = JuMP.@variable(sp, [1:1], base_name = String(Lab.DEFICIT))
            JuMP.set_lower_bound(sp[Lab.DEFICIT][1], 0.0)
            # No upper bound set -- unbounded above

            SDDP.@stageobjective(sp, 1000.0 * sum(sp[Lab.DEFICIT]))
            return nothing
        end

        # Should emit a warning about no upper bound
        test_logger = TestLogger(; min_level = Logging.Warn)
        mags = with_logger(test_logger) do
            return Utils.compute_model_magnitudes(model)
        end

        @test haskey(mags, Lab.DEFICIT)
        # max_magnitude should fall back to hardcoded value since no upper bound
        @test mags[Lab.DEFICIT].max_magnitude == 50_000.0

        # Check that warning was emitted
        warn_logs = filter(l -> l.level == Logging.Warn, test_logger.logs)
        deficit_warns = filter(
            l ->
                occursin("DEFICIT", string(l.message)) &&
                    occursin("upper bound", string(l.message)),
            warn_logs,
        )
        @test length(deficit_warns) >= 1
    end

    @testset "model-derived-magnitudes-fully-unbounded-fallback" begin
        # Build a model where LOAD has no bounds at all
        model = SDDP.LinearPolicyGraph(;
            stages = 2, sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        ) do sp, t
            sp[Lab.LOAD] = JuMP.@variable(sp, [1:1], base_name = String(Lab.LOAD))
            # No bounds set at all

            SDDP.@stageobjective(sp, 0.0)
            return nothing
        end

        # Should emit a warning about no bounds
        test_logger = TestLogger(; min_level = Logging.Warn)
        mags = with_logger(test_logger) do
            return Utils.compute_model_magnitudes(model)
        end

        @test haskey(mags, Lab.LOAD)
        # Should fall back to hardcoded values
        @test mags[Lab.LOAD].max_magnitude == 50_000.0
        @test mags[Lab.LOAD].min_magnitude == 0.0

        # Check that warning was emitted
        warn_logs = filter(l -> l.level == Logging.Warn, test_logger.logs)
        load_warns = filter(
            l ->
                occursin("LOAD", string(l.message)) &&
                    occursin("no bounds", string(l.message)),
            warn_logs,
        )
        @test length(load_warns) >= 1
    end

    @testset "report-with-custom-magnitudes" begin
        # Create a JuMP model with a variable
        jmodel = JuMP.Model()
        jmodel[Lab.THERMAL_GENERATION] = JuMP.@variable(
            jmodel, [1:2], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound.(jmodel[Lab.THERMAL_GENERATION], 0.0)
        JuMP.set_upper_bound.(jmodel[Lab.THERMAL_GENERATION], 150.0)

        # Create custom magnitudes dict (simulating model-derived values)
        custom_mags = Dict{Symbol,Utils.VariableUnitInfo}(
            Lab.THERMAL_GENERATION =>
                Utils.VariableUnitInfo(Lab.THERMAL_GENERATION, Utils.MW, 0.0, 150.0),
        )

        report = Utils.get_coefficient_magnitude_report(jmodel; magnitudes = custom_mags)

        @test nrow(report) == 1
        thermal_row = report[1, :]
        @test thermal_row.variable == String(Lab.THERMAL_GENERATION)
        # expected_max_magnitude should use custom value (150.0), not hardcoded (10_000.0)
        @test thermal_row.expected_max_magnitude == 150.0
        # magnitude_ratio should be 150.0 / 150.0 = 1.0
        @test thermal_row.magnitude_ratio == 1.0
    end

    @testset "backward-compat-no-magnitudes-param" begin
        # Verify that calling without magnitudes parameter behaves identically to current
        jmodel = JuMP.Model()
        jmodel[Lab.THERMAL_GENERATION] = JuMP.@variable(
            jmodel, [1:2], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound.(jmodel[Lab.THERMAL_GENERATION], 0.0)
        JuMP.set_upper_bound.(jmodel[Lab.THERMAL_GENERATION], 5_000.0)

        report = Utils.get_coefficient_magnitude_report(jmodel)

        @test nrow(report) == 1
        thermal_row = report[1, :]
        @test thermal_row.expected_max_magnitude == 10_000.0  # hardcoded value
        @test thermal_row.magnitude_ratio == 5_000.0 / 10_000.0
    end

    @testset "multi-stage-aggregation" begin
        # Build a model with 4 stages where different stages have different bounds
        model = SDDP.LinearPolicyGraph(;
            stages = 4, sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        ) do sp, t
            sp[Lab.THERMAL_GENERATION] = JuMP.@variable(
                sp, [1:1], base_name = String(Lab.THERMAL_GENERATION)
            )
            JuMP.set_lower_bound(sp[Lab.THERMAL_GENERATION][1], 0.0)
            # Different upper bounds per stage
            JuMP.set_upper_bound(sp[Lab.THERMAL_GENERATION][1], 100.0 * t)

            SDDP.@stageobjective(sp, sum(sp[Lab.THERMAL_GENERATION]))
            return nothing
        end

        mags = Utils.compute_model_magnitudes(model)

        @test haskey(mags, Lab.THERMAL_GENERATION)
        # max_magnitude should be max across all 4 stages = 100.0 * 4 = 400.0
        @test mags[Lab.THERMAL_GENERATION].max_magnitude == 400.0
        @test mags[Lab.THERMAL_GENERATION].min_magnitude == 0.0
    end

    @testset "magnitude-ratio-warning" begin
        # Create a model where the ratio exceeds the threshold
        jmodel = JuMP.Model()
        jmodel[Lab.THERMAL_GENERATION] = JuMP.@variable(
            jmodel, [1:1], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound(jmodel[Lab.THERMAL_GENERATION][1], 0.0)
        JuMP.set_upper_bound(jmodel[Lab.THERMAL_GENERATION][1], 5_000.0)

        # Custom magnitudes with a small max_magnitude to trigger high ratio
        custom_mags = Dict{Symbol,Utils.VariableUnitInfo}(
            Lab.THERMAL_GENERATION =>
                Utils.VariableUnitInfo(Lab.THERMAL_GENERATION, Utils.MW, 0.0, 100.0),
        )

        # ratio = 5000 / 100 = 50.0, which exceeds 10.0
        test_logger = TestLogger(; min_level = Logging.Warn)
        report = with_logger(test_logger) do
            return Utils.get_coefficient_magnitude_report(jmodel; magnitudes = custom_mags)
        end

        @test report[1, :magnitude_ratio] == 50.0

        # Check that a ratio warning was emitted
        warn_logs = filter(l -> l.level == Logging.Warn, test_logger.logs)
        ratio_warns = filter(l -> occursin("magnitude ratio", string(l.message)), warn_logs)
        @test length(ratio_warns) >= 1
    end

    @testset "magnitude-ratio-low-warning" begin
        # Create a model where the ratio is below the low threshold
        jmodel = JuMP.Model()
        jmodel[Lab.THERMAL_GENERATION] = JuMP.@variable(
            jmodel, [1:1], base_name = String(Lab.THERMAL_GENERATION)
        )
        JuMP.set_lower_bound(jmodel[Lab.THERMAL_GENERATION][1], 0.0)
        JuMP.set_upper_bound(jmodel[Lab.THERMAL_GENERATION][1], 0.5)

        # Custom magnitudes with a large max_magnitude to trigger low ratio
        custom_mags = Dict{Symbol,Utils.VariableUnitInfo}(
            Lab.THERMAL_GENERATION =>
                Utils.VariableUnitInfo(Lab.THERMAL_GENERATION, Utils.MW, 0.0, 10_000.0),
        )

        # ratio = 0.5 / 10_000.0 = 0.00005, which is below 0.01
        test_logger = TestLogger(; min_level = Logging.Warn)
        report = with_logger(test_logger) do
            return Utils.get_coefficient_magnitude_report(jmodel; magnitudes = custom_mags)
        end

        @test report[1, :magnitude_ratio] == 0.5 / 10_000.0

        # Check that a ratio warning was emitted
        warn_logs = filter(l -> l.level == Logging.Warn, test_logger.logs)
        ratio_warns = filter(l -> occursin("magnitude ratio", string(l.message)), warn_logs)
        @test length(ratio_warns) >= 1
    end

    @testset "variables-not-in-model-skipped" begin
        # Build a model with only THERMAL_GENERATION (no other registered variables)
        model = SDDP.LinearPolicyGraph(;
            stages = 2, sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        ) do sp, t
            sp[Lab.THERMAL_GENERATION] = JuMP.@variable(
                sp, [1:1], base_name = String(Lab.THERMAL_GENERATION)
            )
            JuMP.set_lower_bound(sp[Lab.THERMAL_GENERATION][1], 0.0)
            JuMP.set_upper_bound(sp[Lab.THERMAL_GENERATION][1], 100.0)

            SDDP.@stageobjective(sp, sum(sp[Lab.THERMAL_GENERATION]))
            return nothing
        end

        mags = Utils.compute_model_magnitudes(model)

        # Only THERMAL_GENERATION should be in the result
        @test haskey(mags, Lab.THERMAL_GENERATION)
        @test length(mags) == 1
        # Variables not in the model should NOT appear (silently skipped)
        @test !haskey(mags, Lab.DEFICIT)
        @test !haskey(mags, Lab.STORED_VOLUME)
    end

    @testset "integration-1dtoy" begin
        e = CompositeException()
        study = SDDPlab.read_study(example_dir; e = e)
        model = SDDPlab.build(study, HiGHS.Optimizer)

        mags = Utils.compute_model_magnitudes(model.policy_graph)

        # From 1dtoy: thermals have max_generation = 15.0
        @test haskey(mags, Lab.THERMAL_GENERATION)
        @test mags[Lab.THERMAL_GENERATION].max_magnitude == 15.0

        # From 1dtoy: hydro has max_storage = 100.0
        @test haskey(mags, Lab.STORED_VOLUME)
        @test mags[Lab.STORED_VOLUME].max_magnitude == 100.0

        # DEFICIT should be present (from buses) -- has lower bound 0 but no explicit upper bound
        @test haskey(mags, Lab.DEFICIT)

        # TURBINED_FLOW should be present (from hydros)
        @test haskey(mags, Lab.TURBINED_FLOW)

        # Verify model-derived magnitudes differ from hardcoded for THERMAL_GENERATION
        @test mags[Lab.THERMAL_GENERATION].max_magnitude !=
            Utils.VARIABLE_UNITS_REGISTRY[Lab.THERMAL_GENERATION].max_magnitude

        # Verify that using model-derived magnitudes in the report works
        first_node = first(values(model.policy_graph.nodes))
        sp = first_node.subproblem
        report = Utils.get_coefficient_magnitude_report(sp; magnitudes = mags)
        @test report isa DataFrame
        @test nrow(report) > 0

        # Verify expected_max_magnitude uses model-derived values
        thermal_rows = filter(row -> row.variable == String(Lab.THERMAL_GENERATION), report)
        if nrow(thermal_rows) > 0
            @test thermal_rows[1, :expected_max_magnitude] == 15.0
        end
    end
end
