import SDDPlab: Engines
using SDDP: SDDP
using JuMP: JuMP
using GLPK: GLPK

@testset "engines-sddp-diagnostics" begin
    # -----------------------------------------------------------------------
    # DiagnosticsConfig JSONC parsing
    # -----------------------------------------------------------------------
    @testset "diagnostics-config-valid" begin
        d = Dict{String,Any}(
            "run_numerical_report" => true,
            "warn_threshold" => 1e6,
            "halt_threshold" => 1e10,
        )
        e = CompositeException()
        result = Engines.DiagnosticsConfig(d, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.run_numerical_report == true
        @test result.warn_threshold == 1e6
        @test result.halt_threshold == 1e10
    end

    @testset "diagnostics-config-disabled" begin
        d = Dict{String,Any}(
            "run_numerical_report" => false,
            "warn_threshold" => 1e6,
            "halt_threshold" => 1e10,
        )
        e = CompositeException()
        result = Engines.DiagnosticsConfig(d, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.run_numerical_report == false
    end

    @testset "diagnostics-config-halt-lt-warn-rejected" begin
        d = Dict{String,Any}(
            "run_numerical_report" => true,
            "warn_threshold" => 1e10,
            "halt_threshold" => 1e6,
        )
        e = CompositeException()
        result = Engines.DiagnosticsConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "diagnostics-config-missing-key" begin
        d = Dict{String,Any}(
            "run_numerical_report" => true,
            "warn_threshold" => 1e6,
        )
        e = CompositeException()
        result = Engines.DiagnosticsConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "diagnostics-config-negative-threshold-rejected" begin
        d = Dict{String,Any}(
            "run_numerical_report" => true,
            "warn_threshold" => -1.0,
            "halt_threshold" => 1e10,
        )
        e = CompositeException()
        result = Engines.DiagnosticsConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    # -----------------------------------------------------------------------
    # __build_diagnostics! with optional key
    # -----------------------------------------------------------------------
    @testset "build-diagnostics-missing-key-defaults" begin
        d = Dict{String,Any}()
        e = CompositeException()
        result = Engines.__build_diagnostics!(d, e)
        @test result == true
        @test length(e) == 0
        @test d["diagnostics"] isa Engines.DiagnosticsConfig
        @test d["diagnostics"].run_numerical_report == false
        @test d["diagnostics"].warn_threshold == 1e6
        @test d["diagnostics"].halt_threshold == 1e10
    end

    @testset "build-diagnostics-valid-dict" begin
        d = Dict{String,Any}(
            "diagnostics" => Dict{String,Any}(
                "run_numerical_report" => true,
                "warn_threshold" => 1e5,
                "halt_threshold" => 1e8,
            ),
        )
        e = CompositeException()
        result = Engines.__build_diagnostics!(d, e)
        @test result == true
        @test length(e) == 0
        @test d["diagnostics"] isa Engines.DiagnosticsConfig
        @test d["diagnostics"].run_numerical_report == true
        @test d["diagnostics"].warn_threshold == 1e5
        @test d["diagnostics"].halt_threshold == 1e8
    end

    @testset "build-diagnostics-invalid-type" begin
        d = Dict{String,Any}("diagnostics" => "not_a_dict")
        e = CompositeException()
        result = Engines.__build_diagnostics!(d, e)
        @test result == false
        @test length(e) > 0
    end

    # -----------------------------------------------------------------------
    # SDDPEngine construction with and without diagnostics key
    # -----------------------------------------------------------------------
    @testset "sddp-engine-without-diagnostics-key" begin
        policy_dict = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" => Dict{String,Any}(
                "kind" => "Expectation", "params" => Dict{String,Any}()
            ),
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        simulation_dict = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        params = Dict{String,Any}(
            "policy" => policy_dict,
            "simulation" => simulation_dict,
        )
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.diagnostics.run_numerical_report == false
        @test result.diagnostics.warn_threshold == 1e6
        @test result.diagnostics.halt_threshold == 1e10
    end

    @testset "sddp-engine-with-diagnostics-key" begin
        policy_dict = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" => Dict{String,Any}(
                "kind" => "Expectation", "params" => Dict{String,Any}()
            ),
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        simulation_dict = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        diagnostics_dict = Dict{String,Any}(
            "run_numerical_report" => true,
            "warn_threshold" => 1e4,
            "halt_threshold" => 1e8,
        )
        params = Dict{String,Any}(
            "policy" => policy_dict,
            "simulation" => simulation_dict,
            "diagnostics" => diagnostics_dict,
        )
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.diagnostics.run_numerical_report == true
        @test result.diagnostics.warn_threshold == 1e4
        @test result.diagnostics.halt_threshold == 1e8
    end

    # -----------------------------------------------------------------------
    # run_diagnostics function behavior
    # -----------------------------------------------------------------------
    @testset "run-diagnostics-disabled-returns-true" begin
        config = Engines.DiagnosticsConfig(false, 1e6, 1e10)
        # When diagnostics is disabled, the model is never inspected
        model = SDDP.LinearPolicyGraph(;
            stages = 2, lower_bound = 0.0, optimizer = GLPK.Optimizer
        ) do sp, t
            JuMP.@variable(sp, 0 <= x <= 10, SDDP.State, initial_value = 5)
            SDDP.@stageobjective(sp, x.out)
        end
        @test Engines.run_diagnostics(model, config) == true
    end

    @testset "run-diagnostics-enabled-basic-model" begin
        config = Engines.DiagnosticsConfig(true, 1e6, 1e10)
        model = SDDP.LinearPolicyGraph(;
            stages = 2, lower_bound = 0.0, optimizer = GLPK.Optimizer
        ) do sp, t
            JuMP.@variable(sp, 0 <= x <= 100, SDDP.State, initial_value = 50)
            JuMP.@variable(sp, 0 <= u <= 50)
            JuMP.@constraint(sp, x.out == x.in - u)
            SDDP.@stageobjective(sp, u)
        end
        result = Engines.run_diagnostics(model, config)
        @test result == true
    end

    @testset "run-diagnostics-halt-on-extreme-ratio" begin
        # Build a model with extreme coefficient ranges to trigger halt
        config = Engines.DiagnosticsConfig(true, 1e2, 1e4)
        model = SDDP.LinearPolicyGraph(;
            stages = 2, lower_bound = 0.0, optimizer = GLPK.Optimizer
        ) do sp, t
            JuMP.@variable(sp, 0 <= x <= 1e8, SDDP.State, initial_value = 1e4)
            JuMP.@variable(sp, 0 <= u <= 1e-2)
            JuMP.@constraint(sp, x.out == x.in - 1e6 * u)
            SDDP.@stageobjective(sp, 1e-4 * u)
        end
        result = Engines.run_diagnostics(model, config)
        # With such extreme coefficients and tight thresholds, halt should trigger
        @test result == false
    end

    @testset "run-diagnostics-warn-but-no-halt" begin
        # Build a model with moderate coefficient ranges: triggers warn but not halt
        config = Engines.DiagnosticsConfig(true, 1e2, 1e20)
        model = SDDP.LinearPolicyGraph(;
            stages = 2, lower_bound = 0.0, optimizer = GLPK.Optimizer
        ) do sp, t
            JuMP.@variable(sp, 0 <= x <= 1e6, SDDP.State, initial_value = 1e3)
            JuMP.@variable(sp, 0 <= u <= 50)
            JuMP.@constraint(sp, x.out == x.in - u)
            SDDP.@stageobjective(sp, u)
        end
        result = Engines.run_diagnostics(model, config)
        # Should warn but still return true (no halt)
        @test result == true
    end
end
