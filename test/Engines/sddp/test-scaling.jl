import SDDPlab: Engines
import SDDPlab: System

using SDDP: SDDP
using Graphs

@testset "engines-sddp-scaling" begin

    # JSONC PARSING TESTS ----------------------------------------------------------------

    @testset "no-scaling-from-dict" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        result = Engines.NoScaling(d, e)
        @test typeof(result) === Engines.NoScaling
        @test length(e) == 0
    end

    @testset "auto-scaling-from-dict" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        result = Engines.AutoScaling(d, e)
        @test typeof(result) === Engines.AutoScaling
        @test length(e) == 0
    end

    @testset "scaling-backward-compat-no-key" begin
        d = Dict{String,Any}(
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
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.scaling) === Engines.NoScaling
    end

    @testset "scaling-kind-factory-noscaling" begin
        d = Dict{String,Any}(
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
            "scaling" => Dict{String,Any}(
                "kind" => "NoScaling",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.scaling) === Engines.NoScaling
    end

    @testset "scaling-kind-factory-autoscaling" begin
        d = Dict{String,Any}(
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
            "scaling" => Dict{String,Any}(
                "kind" => "AutoScaling",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.scaling) === Engines.AutoScaling
    end

    @testset "scaling-invalid-kind" begin
        d = Dict{String,Any}(
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
            "scaling" => Dict{String,Any}(
                "kind" => "NonExistentScaling",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result === nothing
        @test length(e) > 0
    end

    # SCALING CONFIG TESTS ---------------------------------------------------------------

    @testset "no-scaling-config" begin
        config = Engines.no_scaling_config()
        @test config isa Engines.ScalingConfig
        @test Engines.get_scaling_factor(config, :STORAGE) == 1.0
        @test Engines.get_scaling_factor(config, :HYDRO_GENERATION) == 1.0
        @test Engines.get_scaling_factor(config, :THERMAL_GENERATION) == 1.0
        @test Engines.get_scaling_factor(config, :DEFICIT) == 1.0
        @test Engines.get_scaling_factor(config, :NONEXISTENT) == 1.0
    end

    @testset "scaling-config-lookup" begin
        factors = Dict{Symbol,Float64}(
            :STORAGE => 50000.0,
            :HYDRO_GENERATION => 500.0,
        )
        config = Engines.ScalingConfig(factors)
        @test Engines.get_scaling_factor(config, :STORAGE) == 50000.0
        @test Engines.get_scaling_factor(config, :HYDRO_GENERATION) == 500.0
        @test Engines.get_scaling_factor(config, :NONEXISTENT) == 1.0
    end

    @testset "is-identity-scaling" begin
        identity_config = Engines.no_scaling_config()
        @test Engines._is_identity_scaling(identity_config) == true

        non_identity = Engines.ScalingConfig(Dict{Symbol,Float64}(:X => 2.0))
        @test Engines._is_identity_scaling(non_identity) == false
    end

    # COMPUTE SCALING FACTORS TESTS -----------------------------------------------------

    @testset "compute-scaling-factors-with-system" begin
        # Build a minimal system for testing
        buses = System.Buses([
            System.Bus(1, "bus1", 50.0),
        ])
        lines = System.Lines(System.Line[])
        hydros = System.Hydros(
            [
                System.Hydro(
                    1, 0, "hydro1", 1, 2.0, 25000.0, 0.0, 50000.0, 0.0, 500.0, 1.0,
                    Ref(buses.entities[1]),
                ),
                System.Hydro(
                    2, 0, "hydro2", 1, 1.5, 10000.0, 0.0, 20000.0, 0.0, 300.0, 1.0,
                    Ref(buses.entities[1]),
                ),
            ],
            Graphs.DiGraph(2),
        )
        thermals = System.Thermals([
            System.Thermal(1, "thermal1", 1, 0.0, 100.0, 10.0, Ref(buses.entities[1])),
        ])
        system = System.SystemData(buses, lines, hydros, thermals)

        config = Engines.compute_scaling_factors(system)

        # Generation: max(500, 300, 100) = 500
        @test Engines.get_scaling_factor(config, :HYDRO_GENERATION) == 500.0
        @test Engines.get_scaling_factor(config, :THERMAL_GENERATION) == 500.0
        @test Engines.get_scaling_factor(config, :DEFICIT) == 500.0

        # Storage and flow are unified via hydro balance consistency:
        # s_stor_candidate = max(50000, 20000) = 50000
        # s_flow_candidate = max(500/2.0, 300/1.5) = max(250, 200) = 250
        # s_hydro = max(50000, 250) = 50000
        @test Engines.get_scaling_factor(config, :STORAGE) == 50000.0
        @test Engines.get_scaling_factor(config, :TURBINED_FLOW) == 50000.0
        @test Engines.get_scaling_factor(config, :SPILLAGE) == 50000.0
        @test Engines.get_scaling_factor(config, :INFLOW) == 50000.0

        # Cost: max(10, 50) = 50
        @test Engines.get_scaling_factor(config, Engines.COST_SCALE) == 50.0
    end

    @testset "compute-scaling-factors-empty-hydros" begin
        buses = System.Buses([
            System.Bus(1, "bus1", 100.0),
        ])
        lines = System.Lines(System.Line[])
        hydros = System.Hydros(System.Hydro[], Graphs.DiGraph(0))
        thermals = System.Thermals([
            System.Thermal(1, "thermal1", 1, 0.0, 200.0, 5.0, Ref(buses.entities[1])),
        ])
        system = System.SystemData(buses, lines, hydros, thermals)

        config = Engines.compute_scaling_factors(system)

        # Storage: empty hydros -> 1.0
        @test Engines.get_scaling_factor(config, :STORAGE) == 1.0

        # Generation: only thermal 200
        @test Engines.get_scaling_factor(config, :HYDRO_GENERATION) == 200.0

        # Flow: empty hydros -> 1.0
        @test Engines.get_scaling_factor(config, :TURBINED_FLOW) == 1.0

        # Cost: max(5, 100) = 100
        @test Engines.get_scaling_factor(config, Engines.COST_SCALE) == 100.0
    end

    @testset "compute-scaling-factors-zero-values" begin
        buses = System.Buses([
            System.Bus(1, "bus1", 0.0),
        ])
        lines = System.Lines(System.Line[])
        hydros = System.Hydros(
            [
                System.Hydro(
                    1, 0, "hydro1", 1, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Ref(buses.entities[1]),
                ),
            ],
            Graphs.DiGraph(1),
        )
        thermals = System.Thermals(System.Thermal[])
        system = System.SystemData(buses, lines, hydros, thermals)

        config = Engines.compute_scaling_factors(system)

        # All zeros should default to 1.0
        @test Engines.get_scaling_factor(config, :STORAGE) == 1.0
        @test Engines.get_scaling_factor(config, :HYDRO_GENERATION) == 1.0
    end

    # APPLY SCALING TESTS ---------------------------------------------------------------

    @testset "apply-scaling-creates-scaled-system" begin
        buses = System.Buses([
            System.Bus(1, "bus1", 50.0),
        ])
        lines = System.Lines(System.Line[])
        hydros = System.Hydros(
            [
                System.Hydro(
                    1, 0, "hydro1", 1, 1.0, 50.0, 0.0, 100.0, 0.0, 60.0, 1.0,
                    Ref(buses.entities[1]),
                ),
            ],
            Graphs.DiGraph(1),
        )
        thermals = System.Thermals([
            System.Thermal(1, "thermal1", 1, 0.0, 15.0, 5.0, Ref(buses.entities[1])),
            System.Thermal(2, "thermal2", 1, 0.0, 15.0, 10.0, Ref(buses.entities[1])),
        ])
        system = System.SystemData(buses, lines, hydros, thermals)

        config = Engines.compute_scaling_factors(system)
        scaled = Engines.apply_scaling(system, config)

        # Unified hydro factor: max(s_stor_candidate=100, s_flow_candidate=60) = 100
        s_stor = Engines.get_scaling_factor(config, :STORAGE)
        @test s_stor == 100.0
        @test scaled.hydros.entities[1].max_storage == 100.0 / s_stor
        @test scaled.hydros.entities[1].initial_storage == 50.0 / s_stor

        # Flow uses the same unified factor
        s_flow = Engines.get_scaling_factor(config, :TURBINED_FLOW)
        @test s_flow == 100.0  # same as storage

        # Generation factor = max(60, 15, 15) = 60
        s_gen = Engines.get_scaling_factor(config, :HYDRO_GENERATION)
        @test s_gen == 60.0
        @test scaled.hydros.entities[1].max_generation == 60.0 / s_gen
        @test scaled.thermals.entities[1].max_generation == 15.0 / s_gen

        # Cost factor = max(5, 10, 50) = 50
        s_cost = Engines.get_scaling_factor(config, Engines.COST_SCALE)
        @test s_cost == 50.0
        @test scaled.thermals.entities[1].cost == 5.0 / s_cost
        @test scaled.buses.entities[1].deficit_cost == 50.0 / s_cost

        # Productivity scaling: prod_scaled = prod * s_flow / s_gen
        @test scaled.hydros.entities[1].productivity == 1.0 * s_flow / s_gen
    end

    # UNSCALING TESTS -------------------------------------------------------------------

    @testset "unscale-identity-is-noop" begin
        config = Engines.no_scaling_config()
        sims = [[Dict{Symbol,Any}(:X => 42.0, :Y => [1.0, 2.0])]]
        result = Engines._unscale_simulations(sims, config)
        @test result === sims  # Should return the same object
    end

    @testset "variable-unscale-factors" begin
        factors = Dict{Symbol,Float64}(
            :STORAGE => 100.0,
            :HYDRO_GENERATION => 60.0,
            :THERMAL_GENERATION => 60.0,
            :DEFICIT => 60.0,
            :TURBINED_FLOW => 60.0,
            :SPILLAGE => 60.0,
            :OUTFLOW => 60.0,
            :INFLOW => 60.0,
            :DIRECT_EXCHANGE => 1.0,
            :REVERSE_EXCHANGE => 1.0,
            Engines.FLOW_SCALE => 60.0,
            Engines.COST_SCALE => 50.0,
        )
        config = Engines.ScalingConfig(factors)

        # Primal variables
        @test Engines._get_variable_unscale_factor(:STORAGE, config) == 100.0
        @test Engines._get_variable_unscale_factor(:HYDRO_GENERATION, config) == 60.0
        @test Engines._get_variable_unscale_factor(:THERMAL_GENERATION, config) == 60.0
        @test Engines._get_variable_unscale_factor(:INFLOW, config) == 60.0

        # Dual variables
        @test Engines._get_variable_unscale_factor(:MARGINAL_COST, config) == 50.0

        # Cost variables
        @test Engines._get_variable_unscale_factor(:stage_objective, config) == 50.0 * 60.0
        @test Engines._get_variable_unscale_factor(:TOTAL_COST, config) == 50.0 * 60.0
    end
end
