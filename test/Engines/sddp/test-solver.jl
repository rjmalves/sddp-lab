import SDDPlab: Engines
using HiGHS: HiGHS
import MathOptInterface as MOI

@testset "engines-sddp-solver" begin
    # -----------------------------------------------------------------------
    # SolverConfig JSONC parsing
    # -----------------------------------------------------------------------
    @testset "solver-config-valid-name-and-attributes" begin
        d = Dict{String,Any}(
            "name" => "HiGHS",
            "attributes" => Dict{String,Any}("output_flag" => false),
        )
        e = CompositeException()
        result = Engines.SolverConfig(d, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.solver_name == "HiGHS"
        @test result.attributes == Dict{String,Any}("output_flag" => false)
    end

    @testset "solver-config-valid-name-only-no-attributes" begin
        d = Dict{String,Any}("name" => "HiGHS")
        e = CompositeException()
        result = Engines.SolverConfig(d, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.solver_name == "HiGHS"
        @test result.attributes == Dict{String,Any}()
    end

    @testset "solver-config-missing-name-rejected" begin
        d = Dict{String,Any}("attributes" => Dict{String,Any}())
        e = CompositeException()
        result = Engines.SolverConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "solver-config-empty-name-rejected" begin
        d = Dict{String,Any}("name" => "")
        e = CompositeException()
        result = Engines.SolverConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    @testset "solver-config-invalid-attributes-type-rejected" begin
        d = Dict{String,Any}("name" => "HiGHS", "attributes" => "not_a_dict")
        e = CompositeException()
        result = Engines.SolverConfig(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    # -----------------------------------------------------------------------
    # __build_solver! with optional key
    # -----------------------------------------------------------------------
    @testset "build-solver-missing-key-defaults" begin
        d = Dict{String,Any}()
        e = CompositeException()
        result = Engines.__build_solver!(d, e)
        @test result == true
        @test length(e) == 0
        @test d["solver"] isa Engines.SolverConfig
        @test d["solver"].solver_name == "HiGHS"
        @test d["solver"].attributes == Dict{String,Any}()
    end

    @testset "build-solver-valid-dict" begin
        d = Dict{String,Any}(
            "solver" => Dict{String,Any}(
                "name" => "HiGHS",
                "attributes" => Dict{String,Any}("output_flag" => false),
            ),
        )
        e = CompositeException()
        result = Engines.__build_solver!(d, e)
        @test result == true
        @test length(e) == 0
        @test d["solver"] isa Engines.SolverConfig
        @test d["solver"].solver_name == "HiGHS"
        @test d["solver"].attributes == Dict{String,Any}("output_flag" => false)
    end

    @testset "build-solver-invalid-type" begin
        d = Dict{String,Any}("solver" => "not_a_dict")
        e = CompositeException()
        result = Engines.__build_solver!(d, e)
        @test result == false
        @test length(e) > 0
    end

    # -----------------------------------------------------------------------
    # create_optimizer
    # -----------------------------------------------------------------------
    @testset "create-optimizer-highs-default" begin
        config = Engines.SolverConfig("HiGHS", Dict{String,Any}())
        factory = Engines.create_optimizer(config)
        @test factory isa Function
        opt = factory()
        @test opt isa HiGHS.Optimizer
    end

    @testset "create-optimizer-highs-with-attributes" begin
        config = Engines.SolverConfig("HiGHS", Dict{String,Any}("output_flag" => false))
        factory = Engines.create_optimizer(config)
        opt = factory()
        @test opt isa HiGHS.Optimizer
        val = MOI.get(opt, MOI.RawOptimizerAttribute("output_flag"))
        @test val == false
    end

    @testset "create-optimizer-unsupported-solver" begin
        config = Engines.SolverConfig("UnknownSolver", Dict{String,Any}())
        @test_throws ErrorException Engines.create_optimizer(config)
        try
            Engines.create_optimizer(config)
        catch ex
            @test occursin("Unsupported solver", ex.msg)
            @test occursin("UnknownSolver", ex.msg)
        end
    end

    # -----------------------------------------------------------------------
    # SDDPEngine construction with and without solver key (dict-based)
    # -----------------------------------------------------------------------
    @testset "sddp-engine-without-solver-key-defaults" begin
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
        @test result.solver.solver_name == "HiGHS"
        @test result.solver.attributes == Dict{String,Any}()
    end

    @testset "sddp-engine-with-solver-key" begin
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
        solver_dict = Dict{String,Any}(
            "name" => "HiGHS",
            "attributes" => Dict{String,Any}("output_flag" => false),
        )
        params = Dict{String,Any}(
            "policy" => policy_dict,
            "simulation" => simulation_dict,
            "solver" => solver_dict,
        )
        e = CompositeException()
        result = Engines.SDDPEngine(params, e)
        @test result !== nothing
        @test length(e) == 0
        @test result.solver.solver_name == "HiGHS"
        @test result.solver.attributes == Dict{String,Any}("output_flag" => false)
    end

    # -----------------------------------------------------------------------
    # SDDPEngine direct struct construction with solver
    # -----------------------------------------------------------------------
    @testset "sddp-engine-direct-construction-with-solver" begin
        convergence = Engines.Convergence(10, 128, [Engines.IterationLimit(128)])
        policy = Engines.SDDPPolicyTaskDefinition(
            convergence,
            Engines.Expectation(),
            Engines.Serial(),
            Engines.DefaultSampling(),
            Engines.DefaultDuality(),
            Engines.DefaultForwardPassStrategy(),
            Engines.SingleCut(),
            Engines.NoScaling(),
        )
        simulation = Engines.SDDPSimulationTaskDefinition(
            100, Engines.Serial(), Engines.DefaultSampling()
        )
        diag = Engines.DiagnosticsConfig(false, 1e6, 1e10)
        solver = Engines.SolverConfig("HiGHS", Dict{String,Any}("output_flag" => false))
        engine = Engines.SDDPEngine(policy, simulation, diag, solver, Engines.InflowNone())
        @test engine.solver.solver_name == "HiGHS"
        @test engine.solver.attributes == Dict{String,Any}("output_flag" => false)
    end
end
