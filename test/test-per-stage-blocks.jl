import SDDPlab: Engines, System, Scenarios, Lab, Inputs
using SDDPlab: SDDPlab
using SDDP: SDDP
using JuMP: JuMP
using HiGHS: HiGHS
using Graphs
using Dates
using Suppressor
using Test
using DataFrames: DataFrames
using CSV: CSV

# =====================================================================================
# Helper: build a minimal SystemData for unit tests
# =====================================================================================

function _pstb_make_buses(n::Int; deficit_cost::Float64 = 50.0)
    buses = [System.Bus(i, "bus$i", deficit_cost) for i in 1:n]
    return System.Buses(buses)
end

function _pstb_make_system(; num_buses::Int = 1, num_thermals::Int = 2, num_hydros::Int = 1)
    buses = _pstb_make_buses(num_buses)
    thermals = System.Thermals([
        System.Thermal(
            i,
            "thermal$i",
            buses.entities[min(i, num_buses)].id,
            0.0,
            100.0,
            5.0 * i,
            Ref(buses.entities[min(i, num_buses)]),
        ) for i in 1:num_thermals
    ])
    hydro_entities = [
        System.Hydro(
            i,
            0,
            "hydro$i",
            buses.entities[min(i, num_buses)].id,
            1.0,
            50.0,
            0.0,
            100.0,
            0.0,
            60.0,
            0.01,
            Ref(buses.entities[min(i, num_buses)]),
        ) for i in 1:num_hydros
    ]
    g = Graphs.DiGraph(num_hydros)
    hydros = System.Hydros(hydro_entities, g)
    lines = System.Lines(System.Line[])
    noncontrollables = System.NonControllables(System.NonControllable[])
    energycontracts = System.EnergyContracts(System.EnergyContract[])
    pumpingstations = System.PumpingStations(System.PumpingStation[])
    return System.SystemData(
        buses, lines, hydros, thermals, noncontrollables, energycontracts, pumpingstations
    )
end

# Build a minimal ScenariosData from the 1dtoy example, then replace block_configs
# with the given dict. This avoids duplicating the full scenarios construction.
function _pstb_make_scenarios(
    original::Scenarios.ScenariosData, block_configs::Dict{Int,Scenarios.BlockConfig}
)
    return Scenarios.ScenariosData(
        original.seed,
        original.initial_season,
        original.branchings,
        Scenarios.get_graph(original),
        original.inflow,
        original.load,
        block_configs,
        original.markov_chain,
    )
end

# Build a fast SDDPEngine for tests (3 iterations, Serial, HiGHS).
function _pstb_make_engine(original_engine)
    convergence = Engines.Convergence(1, 3, [Engines.IterationLimit(3)])
    policy_def = Engines.SDDPPolicyTaskDefinition(
        convergence,
        original_engine.policy.risk_measure,
        Engines.Serial(),
        Engines.DefaultSampling(),
        Engines.DefaultDuality(),
        Engines.DefaultForwardPassStrategy(),
        Engines.SingleCut(),
        Engines.NoScaling(),
        Engines.TrainingLogConfig("", 1, false, 1),
    )
    sim_def = Engines.SDDPSimulationTaskDefinition(
        5, Engines.Serial(), Engines.DefaultSampling()
    )
    return Engines.SDDPEngine(
        policy_def,
        sim_def,
        Engines.DiagnosticsConfig(false, 1e6, 1e10),
        Engines.SolverConfig("HiGHS", Dict{String,Any}()),
        Engines.InflowNone(),
        nothing,
        Engines.DebugConfig(false, Any[], "mof", false, 60.0),
    )
end

# =====================================================================================
# Tests
# =====================================================================================

@testset "per-stage-blocks" begin

    # The 1dtoy example dir is set in runtests.jl as `example_dir`.
    # Stage durations (from graph.jsonc 2024 dates):
    #   Stage 1: Jan = 744 h   Stage 2: Feb = 696 h (leap year)
    #   Stage 3: Mar = 744 h   Stage 4: Apr = 720 h

    # ---------------------------------------------------------------------------------
    # 1. ScenariosData construction with per-stage block configs (different K per stage)
    # ---------------------------------------------------------------------------------
    @testset "construct-scenarios-with-different-k-per-stage" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        old_scenarios = Lab.get_input_module(
            Inputs.get_files(original.inputs), Scenarios.ScenariosData
        )
        num_stages = Scenarios.get_number_of_stages(Scenarios.get_graph(old_scenarios))
        @test num_stages == 4

        # Stage 1: 3 parallel blocks, Stage 2: 2 parallel blocks,
        # Stage 3: 2 chronological blocks, Stage 4: 3 chronological blocks
        block_configs = Dict{Int,Scenarios.BlockConfig}(
            1 => Scenarios.BlockConfig(
                :parallel,
                [
                    Scenarios.Block("peak", 248.0),
                    Scenarios.Block("shoulder", 248.0),
                    Scenarios.Block("offpeak", 248.0),
                ],
            ),
            2 => Scenarios.BlockConfig(
                :parallel,
                [Scenarios.Block("day", 348.0), Scenarios.Block("night", 348.0)],
            ),
            3 => Scenarios.BlockConfig(
                :chronological,
                [Scenarios.Block("first", 372.0), Scenarios.Block("second", 372.0)],
            ),
            4 => Scenarios.BlockConfig(
                :chronological,
                [
                    Scenarios.Block("morning", 240.0),
                    Scenarios.Block("afternoon", 240.0),
                    Scenarios.Block("evening", 240.0),
                ],
            ),
        )

        new_scenarios = _pstb_make_scenarios(old_scenarios, block_configs)

        # Verify per-stage configs are accessible
        bc1 = Scenarios.get_block_config(new_scenarios, 1)
        @test bc1.mode == :parallel
        @test Scenarios.num_blocks(bc1) == 3
        @test Scenarios.get_block_names(bc1) == ["peak", "shoulder", "offpeak"]

        bc2 = Scenarios.get_block_config(new_scenarios, 2)
        @test bc2.mode == :parallel
        @test Scenarios.num_blocks(bc2) == 2
        @test Scenarios.get_block_names(bc2) == ["day", "night"]

        bc3 = Scenarios.get_block_config(new_scenarios, 3)
        @test bc3.mode == :chronological
        @test Scenarios.num_blocks(bc3) == 2
        @test Scenarios.get_block_names(bc3) == ["first", "second"]

        bc4 = Scenarios.get_block_config(new_scenarios, 4)
        @test bc4.mode == :chronological
        @test Scenarios.num_blocks(bc4) == 3
        @test Scenarios.get_block_names(bc4) == ["morning", "afternoon", "evening"]

        # Stage not in dict falls back to default (no blocks)
        bc5 = Scenarios.get_block_config(new_scenarios, 99)
        @test Scenarios.has_blocks(bc5) == false
        @test Scenarios.num_blocks(bc5) == 1
    end

    # ---------------------------------------------------------------------------------
    # 2. Per-stage block config from JSON: "stage_blocks" parsing
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-json-parsing" begin
        # Build scenarios dict directly to test the parser
        base_d = Dict{String,Any}(
            "seed" => 42,
            "initial_season" => 1,
            "branchings" => 1,
            "graph" => Dict{String,Any}(
                "params" => Dict{String,Any}(
                    "nodes" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "stage" => 1,
                            "start_datetime" => "2024-06-01",
                            "end_datetime" => "2024-07-01",
                        ),
                        Dict{String,Any}(
                            "id" => 2,
                            "stage" => 2,
                            "start_datetime" => "2024-07-01",
                            "end_datetime" => "2024-08-01",
                        ),
                    ],
                    "edges" => [
                        Dict{String,Any}(
                            "source" => 1,
                            "target" => 2,
                            "probability" => 1.0,
                            "discount_rate" => 0.0,
                        ),
                    ],
                ),
            ),
            "inflow" => Dict{String,Any}(
                "stochastic_process" => Dict{String,Any}(
                    "kind" => "Naive",
                    "params" => Dict{String,Any}(
                        "marginal_models" => [
                            Dict{String,Any}(
                                "id" => 1,
                                "distributions" => [
                                    Dict{String,Any}(
                                        "season" => 1,
                                        "kind" => "Normal",
                                        "parameters" => [70.0, 7.0],
                                    ),
                                    Dict{String,Any}(
                                        "season" => 2,
                                        "kind" => "Normal",
                                        "parameters" => [70.0, 7.0],
                                    ),
                                ],
                            ),
                        ],
                        "copulas" => [
                            Dict{String,Any}(
                                "season" => 1,
                                "kind" => "GaussianCopula",
                                "parameters" => [[1.0]],
                            ),
                            Dict{String,Any}(
                                "season" => 2,
                                "kind" => "GaussianCopula",
                                "parameters" => [[1.0]],
                            ),
                        ],
                    ),
                ),
            ),
            "load" => Dict{String,Any}(
                "kind" => "DeterministicLoad",
                "params" => Dict{String,Any}(
                    "values" => [
                        Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0),
                        Dict{String,Any}("bus_id" => 1, "node_id" => 2, "value" => 100.0),
                    ],
                ),
            ),
            # Stage 1: June 2024 = 30 days = 720h; Stage 2: July 2024 = 31 days = 744h
            "stage_blocks" => Dict{String,Any}(
                "1" => Dict{String,Any}(
                    "mode" => "parallel",
                    "definitions" => [
                        Dict{String,Any}("name" => "peak", "duration_hours" => 240.0),
                        Dict{String,Any}("name" => "offpeak", "duration_hours" => 480.0),
                    ],
                ),
                "2" => Dict{String,Any}(
                    "mode" => "chronological",
                    "definitions" => [
                        Dict{String,Any}("name" => "b1", "duration_hours" => 372.0),
                        Dict{String,Any}("name" => "b2", "duration_hours" => 372.0),
                    ],
                ),
            ),
        )

        e = CompositeException()
        sd = Scenarios.ScenariosData(base_d, e)
        @test length(e) == 0
        @test sd !== nothing

        bc1 = Scenarios.get_block_config(sd, 1)
        @test bc1.mode == :parallel
        @test Scenarios.num_blocks(bc1) == 2
        @test Scenarios.get_block_names(bc1) == ["peak", "offpeak"]

        bc2 = Scenarios.get_block_config(sd, 2)
        @test bc2.mode == :chronological
        @test Scenarios.num_blocks(bc2) == 2
    end

    # ---------------------------------------------------------------------------------
    # 3. Error: both "blocks" and "stage_blocks" keys are mutually exclusive
    # ---------------------------------------------------------------------------------
    @testset "both-blocks-and-stage-blocks-is-error" begin
        # Build a parsed Graph so __build_block_config! can access d["graph"]
        graph_dict = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-06-01",
                    "end_datetime" => "2024-07-01",
                ),
            ],
            "edges" => [],
        )
        e_graph = CompositeException()
        parsed_graph = Scenarios.Graph(graph_dict, e_graph)

        d = Dict{String,Any}(
            "graph" => parsed_graph,
            "blocks" => Dict{String,Any}(
                "mode" => "parallel",
                "definitions" =>
                    [Dict{String,Any}("name" => "b1", "duration_hours" => 720.0)],
            ),
            "stage_blocks" => Dict{String,Any}(
                "1" => Dict{String,Any}(
                    "mode" => "parallel",
                    "definitions" => [
                        Dict{String,Any}("name" => "b1", "duration_hours" => 720.0),
                    ],
                ),
            ),
        )

        e = CompositeException()
        Scenarios.__build_block_config!(d, e)
        @test length(e) >= 1
    end

    # ---------------------------------------------------------------------------------
    # 4. Error accumulation: stage_blocks with invalid entries
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-invalid-entry-accumulates-errors" begin
        graph_dict = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-06-01",
                    "end_datetime" => "2024-07-01",
                ),
                Dict{String,Any}(
                    "id" => 2,
                    "stage" => 2,
                    "start_datetime" => "2024-07-01",
                    "end_datetime" => "2024-08-01",
                ),
                Dict{String,Any}(
                    "id" => 3,
                    "stage" => 3,
                    "start_datetime" => "2024-08-01",
                    "end_datetime" => "2024-09-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ),
                Dict{String,Any}(
                    "source" => 2,
                    "target" => 3,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ),
            ],
        )

        # Build the graph directly using the Graph constructor so __build_block_config!
        # can access d["graph"] as a parsed Graph struct.
        e_graph = CompositeException()
        parsed_graph = Scenarios.Graph(graph_dict, e_graph)
        @test length(e_graph) == 0
        @test parsed_graph !== nothing

        d = Dict{String,Any}(
            "graph" => parsed_graph,
            "stage_blocks" => Dict{String,Any}(
                "not_an_int" => Dict{String,Any}(
                    "mode" => "parallel",
                    "definitions" => [
                        Dict{String,Any}("name" => "b1", "duration_hours" => 720.0),
                    ],
                ),
                "2" => "not_a_dict",
                "3" => Dict{String,Any}(
                    "mode" => "invalid_mode",
                    "definitions" => [
                        Dict{String,Any}("name" => "b1", "duration_hours" => 720.0),
                    ],
                ),
            ),
        )

        e = CompositeException()
        Scenarios.__build_block_config!(d, e)
        # Three invalid entries should produce at least 3 errors
        @test length(e) >= 3
    end

    # ---------------------------------------------------------------------------------
    # 5. Legacy "blocks" key emits deprecation warning
    # ---------------------------------------------------------------------------------
    @testset "legacy-blocks-key-deprecation-warning" begin
        # Build a parsed two-stage Graph (June=720h, July=744h)
        graph_dict = Dict{String,Any}(
            "nodes" => [
                Dict{String,Any}(
                    "id" => 1,
                    "stage" => 1,
                    "start_datetime" => "2024-06-01",
                    "end_datetime" => "2024-07-01",
                ),
                Dict{String,Any}(
                    "id" => 2,
                    "stage" => 2,
                    "start_datetime" => "2024-07-01",
                    "end_datetime" => "2024-08-01",
                ),
            ],
            "edges" => [
                Dict{String,Any}(
                    "source" => 1,
                    "target" => 2,
                    "probability" => 1.0,
                    "discount_rate" => 0.0,
                ),
            ],
        )
        e_graph = CompositeException()
        parsed_graph = Scenarios.Graph(graph_dict, e_graph)
        @test parsed_graph !== nothing

        d = Dict{String,Any}(
            "graph" => parsed_graph,
            "blocks" => Dict{String,Any}(
                "mode" => "parallel",
                "definitions" => [
                    Dict{String,Any}("name" => "peak", "duration_hours" => 360.0),
                    Dict{String,Any}("name" => "offpeak", "duration_hours" => 360.0),
                ],
            ),
        )

        e = CompositeException()
        # @warn should fire during __build_block_config! -- parsing succeeds
        result = @test_logs (:warn, r"deprecated"i) Scenarios.__build_block_config!(d, e)
        @test result == true
        @test length(e) == 0

        # Legacy format spreads the single config across all stages
        block_configs = d["block_configs"]
        @test block_configs isa Dict{Int,Scenarios.BlockConfig}
        @test all(Scenarios.num_blocks(bc) == 2 for (_, bc) in block_configs)
    end

    # ---------------------------------------------------------------------------------
    # 6. Build model with per-stage blocks: verify variable dimensions per stage
    # ---------------------------------------------------------------------------------
    @testset "build-model-different-k-per-stage" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        old_files = Inputs.get_files(original.inputs)
        old_scenarios = Lab.get_input_module(old_files, Scenarios.ScenariosData)

        # Stage 1: 3 parallel blocks (744h), Stage 2: 2 parallel blocks (696h),
        # Stage 3: 2 chronological blocks (744h), Stage 4: 3 chronological blocks (720h)
        block_configs = Dict{Int,Scenarios.BlockConfig}(
            1 => Scenarios.BlockConfig(
                :parallel,
                [
                    Scenarios.Block("peak", 248.0),
                    Scenarios.Block("shoulder", 248.0),
                    Scenarios.Block("offpeak", 248.0),
                ],
            ),
            2 => Scenarios.BlockConfig(
                :parallel,
                [Scenarios.Block("day", 348.0), Scenarios.Block("night", 348.0)],
            ),
            3 => Scenarios.BlockConfig(
                :chronological,
                [Scenarios.Block("first", 372.0), Scenarios.Block("second", 372.0)],
            ),
            4 => Scenarios.BlockConfig(
                :chronological,
                [
                    Scenarios.Block("morning", 240.0),
                    Scenarios.Block("afternoon", 240.0),
                    Scenarios.Block("evening", 240.0),
                ],
            ),
        )

        new_scenarios = _pstb_make_scenarios(old_scenarios, block_configs)
        new_files = Lab.InputModule[
            f isa Scenarios.ScenariosData ? new_scenarios : f for f in old_files
        ]
        new_inputs = Inputs.InputsData(Inputs.get_path(original.inputs), new_files)
        engine = _pstb_make_engine(original.engine)
        study = SDDPlab.Study(new_inputs, engine)

        @suppress begin
            model = SDDPlab.build(study, HiGHS.Optimizer)
            @test model !== nothing

            # 1dtoy has 2 thermals, 1 hydro, 1 bus.
            # In SDDP.PolicyGraph, node 1 is the root (dummy starting node with no
            # subproblem). Subproblems are built for nodes 2, 3, 4.
            # Node n maps to stage n via __extract_stage(node) = Int(node), so:
            #   policy_graph[2] → stage 2 block config (2 parallel blocks, 696h)
            #   policy_graph[3] → stage 3 block config (2 chronological blocks, 744h)
            #   policy_graph[4] → stage 4 block config (3 chronological blocks, 720h)

            # Stage 2 (node 2): 2 parallel blocks
            sp2 = model.policy_graph[2].subproblem
            @test size(sp2[Lab.THERMAL_GENERATION]) == (2, 2)
            @test size(sp2[Lab.HYDRO_GENERATION]) == (1, 2)
            @test size(sp2[Lab.DEFICIT]) == (1, 2)
            # Parallel mode: HYDRO_BALANCE is 1D
            @test size(sp2[Lab.HYDRO_BALANCE]) == (1,)
            # Parallel mode: no BLOCK_STORAGE
            @test !haskey(JuMP.object_dictionary(sp2), Lab.BLOCK_STORAGE)

            # Stage 3 (node 3): 2 chronological blocks
            sp3 = model.policy_graph[3].subproblem
            @test size(sp3[Lab.THERMAL_GENERATION]) == (2, 2)
            @test size(sp3[Lab.HYDRO_GENERATION]) == (1, 2)
            @test haskey(JuMP.object_dictionary(sp3), Lab.BLOCK_STORAGE)
            @test size(sp3[Lab.BLOCK_STORAGE]) == (1, 1)  # 1 hydro, K-1=1 intermediate

            # Stage 4 (node 4): 3 chronological blocks
            sp4 = model.policy_graph[4].subproblem
            @test size(sp4[Lab.THERMAL_GENERATION]) == (2, 3)
            @test size(sp4[Lab.HYDRO_GENERATION]) == (1, 3)
            @test haskey(JuMP.object_dictionary(sp4), Lab.BLOCK_STORAGE)
            @test size(sp4[Lab.BLOCK_STORAGE]) == (1, 2)  # 1 hydro, K-1=2 intermediates
        end
    end

    # ---------------------------------------------------------------------------------
    # 7. Build + train + simulate with per-stage blocks (3 iterations)
    # ---------------------------------------------------------------------------------
    @testset "e2e-per-stage-blocks-build-train-simulate" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        old_files = Inputs.get_files(original.inputs)
        old_scenarios = Lab.get_input_module(old_files, Scenarios.ScenariosData)

        block_configs = Dict{Int,Scenarios.BlockConfig}(
            1 => Scenarios.BlockConfig(
                :parallel,
                [
                    Scenarios.Block("peak", 248.0),
                    Scenarios.Block("shoulder", 248.0),
                    Scenarios.Block("offpeak", 248.0),
                ],
            ),
            2 => Scenarios.BlockConfig(
                :parallel,
                [Scenarios.Block("day", 348.0), Scenarios.Block("night", 348.0)],
            ),
            3 => Scenarios.BlockConfig(
                :chronological,
                [Scenarios.Block("first", 372.0), Scenarios.Block("second", 372.0)],
            ),
            4 => Scenarios.BlockConfig(
                :chronological,
                [
                    Scenarios.Block("morning", 240.0),
                    Scenarios.Block("afternoon", 240.0),
                    Scenarios.Block("evening", 240.0),
                ],
            ),
        )

        new_scenarios = _pstb_make_scenarios(old_scenarios, block_configs)
        new_files = Lab.InputModule[
            f isa Scenarios.ScenariosData ? new_scenarios : f for f in old_files
        ]
        new_inputs = Inputs.InputsData(Inputs.get_path(original.inputs), new_files)
        engine = _pstb_make_engine(original.engine)
        study = SDDPlab.Study(new_inputs, engine)

        @suppress begin
            model = SDDPlab.build(study, HiGHS.Optimizer)
            @test model !== nothing

            policy = SDDPlab.train(study, model)
            @test policy !== nothing

            artifact = SDDPlab.simulate(study, model)
            @test artifact !== nothing
        end
    end

    # ---------------------------------------------------------------------------------
    # 8. Save simulation, read back, verify block_index and block_duration_hours columns
    # ---------------------------------------------------------------------------------
    @testset "e2e-per-stage-blocks-output-schema" begin
        e = CompositeException()
        original = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        old_files = Inputs.get_files(original.inputs)
        old_scenarios = Lab.get_input_module(old_files, Scenarios.ScenariosData)

        # Stage 1: 3 parallel blocks (744h), Stage 2: 2 parallel (696h),
        # Stage 3: 2 chronological (744h), Stage 4: 3 chronological (720h)
        block_configs = Dict{Int,Scenarios.BlockConfig}(
            1 => Scenarios.BlockConfig(
                :parallel,
                [
                    Scenarios.Block("peak", 248.0),
                    Scenarios.Block("shoulder", 248.0),
                    Scenarios.Block("offpeak", 248.0),
                ],
            ),
            2 => Scenarios.BlockConfig(
                :parallel,
                [Scenarios.Block("day", 348.0), Scenarios.Block("night", 348.0)],
            ),
            3 => Scenarios.BlockConfig(
                :chronological,
                [Scenarios.Block("first", 372.0), Scenarios.Block("second", 372.0)],
            ),
            4 => Scenarios.BlockConfig(
                :chronological,
                [
                    Scenarios.Block("morning", 240.0),
                    Scenarios.Block("afternoon", 240.0),
                    Scenarios.Block("evening", 240.0),
                ],
            ),
        )

        new_scenarios = _pstb_make_scenarios(old_scenarios, block_configs)
        new_files = Lab.InputModule[
            f isa Scenarios.ScenariosData ? new_scenarios : f for f in old_files
        ]
        new_inputs = Inputs.InputsData(Inputs.get_path(original.inputs), new_files)
        engine = _pstb_make_engine(original.engine)
        study = SDDPlab.Study(new_inputs, engine)

        @suppress begin
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            artifact = SDDPlab.simulate(study, model)

            mktempdir() do tmpdir
                SDDPlab.save_simulation(study, artifact, tmpdir, Lab.CSVFormat())

                thermal_path = joinpath(tmpdir, "operation_thermals.csv")
                @test isfile(thermal_path)

                df = CSV.read(thermal_path, DataFrames.DataFrame)

                # Schema: required columns present
                @test "variable_name" in names(df)
                @test "block_index" in names(df)
                @test "block_duration_hours" in names(df)
                @test "stage" in names(df)
                @test "entity_id" in names(df)
                @test "scenario" in names(df)
                @test "value" in names(df)

                # No _B suffix in variable names
                @test all(!contains(vn, "_B") for vn in df[!, "variable_name"])

                # THERMAL_GENERATION rows are 2D (have block_index)
                thermal_rows = filter(r -> r.variable_name == "THERMAL_GENERATION", df)
                @test !isempty(thermal_rows)
                @test all(!ismissing, thermal_rows[!, "block_index"])

                # The 1dtoy SDDP model has 3 simulation steps (nodes 2, 3, 4).
                # In the output CSV the "stage" column is the 1-based simulation step index.
                # step 1 → graph node 2 (stage 2 config): 2 parallel blocks, 348h each
                # step 2 → graph node 3 (stage 3 config): 2 chronological blocks, 372h each
                # step 3 → graph node 4 (stage 4 config): 3 chronological blocks, 240h each

                # Output stage 1 → graph stage 2 → 2 blocks with durations [348, 348]
                stage1_rows = filter(
                    r ->
                        r.variable_name == "THERMAL_GENERATION" &&
                            r.stage == 1 &&
                            !ismissing(r.block_index),
                    df,
                )
                @test !isempty(stage1_rows)
                block_indices_s1 = sort(unique(skipmissing(stage1_rows[!, "block_index"])))
                @test block_indices_s1 == [1, 2]
                @test all(stage1_rows[!, "block_duration_hours"] .== 348.0)

                # Output stage 2 → graph stage 3 → 2 blocks with durations [372, 372]
                stage2_rows = filter(
                    r ->
                        r.variable_name == "THERMAL_GENERATION" &&
                            r.stage == 2 &&
                            !ismissing(r.block_index),
                    df,
                )
                @test !isempty(stage2_rows)
                block_indices_s2 = sort(unique(skipmissing(stage2_rows[!, "block_index"])))
                @test block_indices_s2 == [1, 2]
                @test all(stage2_rows[!, "block_duration_hours"] .== 372.0)

                # Output stage 3 → graph stage 4 → 3 chronological blocks with 240h each
                stage3_rows = filter(
                    r ->
                        r.variable_name == "THERMAL_GENERATION" &&
                            r.stage == 3 &&
                            !ismissing(r.block_index),
                    df,
                )
                @test !isempty(stage3_rows)
                block_indices_s3 = sort(unique(skipmissing(stage3_rows[!, "block_index"])))
                @test block_indices_s3 == [1, 2, 3]
                @test all(stage3_rows[!, "block_duration_hours"] .== 240.0)
            end
        end
    end

    # ---------------------------------------------------------------------------------
    # 9. E2E with the 1dtoy_per_stage_blocks example case:
    #    read_study -> build -> train -> simulate (verifies scenarios.jsonc is valid)
    # ---------------------------------------------------------------------------------
    @testset "e2e-1dtoy-per-stage-blocks-example" begin
        pstb_example_dir = joinpath(@__DIR__, "..", "example", "1dtoy_per_stage_blocks")
        @test isdir(pstb_example_dir)

        e = CompositeException()
        study = SDDPlab.read_study(pstb_example_dir; e = e)
        @test length(e) == 0
        @test study !== nothing

        # Verify per-stage block configs are loaded correctly
        scenarios = Lab.get_input_module(
            Inputs.get_files(study.inputs), Scenarios.ScenariosData
        )
        bc1 = Scenarios.get_block_config(scenarios, 1)
        @test bc1.mode == :parallel
        @test Scenarios.num_blocks(bc1) == 3

        bc2 = Scenarios.get_block_config(scenarios, 2)
        @test bc2.mode == :parallel
        @test Scenarios.num_blocks(bc2) == 2

        bc3 = Scenarios.get_block_config(scenarios, 3)
        @test bc3.mode == :chronological
        @test Scenarios.num_blocks(bc3) == 2

        bc4 = Scenarios.get_block_config(scenarios, 4)
        @test bc4.mode == :chronological
        @test Scenarios.num_blocks(bc4) == 3

        # Patch engine to use HiGHS + 3 iterations for fast test
        old_files = Inputs.get_files(study.inputs)
        engine = _pstb_make_engine(study.engine)
        fast_study = SDDPlab.Study(study.inputs, engine)

        @suppress begin
            model = SDDPlab.build(fast_study, HiGHS.Optimizer)
            @test model !== nothing

            policy = SDDPlab.train(fast_study, model)
            @test policy !== nothing

            artifact = SDDPlab.simulate(fast_study, model)
            @test artifact !== nothing

            # Save and verify the output schema
            mktempdir() do tmpdir
                SDDPlab.save_simulation(fast_study, artifact, tmpdir, Lab.CSVFormat())
                thermal_path = joinpath(tmpdir, "operation_thermals.csv")
                @test isfile(thermal_path)

                df = CSV.read(thermal_path, DataFrames.DataFrame)
                @test "block_index" in names(df)
                @test "block_duration_hours" in names(df)
                @test all(!contains(vn, "_B") for vn in df[!, "variable_name"])

                # With per-stage blocks: all THERMAL_GENERATION rows have non-missing block_index
                thermal_rows = filter(r -> r.variable_name == "THERMAL_GENERATION", df)
                @test !isempty(thermal_rows)
                @test all(!ismissing, thermal_rows[!, "block_index"])

                # Output stage 3 → graph node 4 (stage 4 config: 3 chrono blocks, 240h each)
                # The SDDP model has 3 simulation steps (nodes 2, 3, 4):
                #   step 1 → graph stage 2: 2 parallel blocks (348h each)
                #   step 2 → graph stage 3: 2 chrono blocks (372h each)
                #   step 3 → graph stage 4: 3 chrono blocks (240h each)
                stage3_thermal = filter(
                    r ->
                        r.variable_name == "THERMAL_GENERATION" &&
                            r.stage == 3 &&
                            !ismissing(r.block_index),
                    df,
                )
                @test !isempty(stage3_thermal)
                block_indices_s3 = sort(
                    unique(skipmissing(stage3_thermal[!, "block_index"]))
                )
                @test block_indices_s3 == [1, 2, 3]
                @test all(stage3_thermal[!, "block_duration_hours"] .== 240.0)
            end
        end
    end

    # ---------------------------------------------------------------------------------
    # 10. Block duration sum validation: mismatched durations fail at ScenariosData build
    # ---------------------------------------------------------------------------------
    @testset "block-duration-mismatch-validation-error" begin
        base_d = Dict{String,Any}(
            "seed" => 42,
            "initial_season" => 1,
            "branchings" => 1,
            "graph" => Dict{String,Any}(
                "params" => Dict{String,Any}(
                    "nodes" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "stage" => 1,
                            "start_datetime" => "2024-06-01",
                            "end_datetime" => "2024-07-01",
                        ),
                        Dict{String,Any}(
                            "id" => 2,
                            "stage" => 2,
                            "start_datetime" => "2024-07-01",
                            "end_datetime" => "2024-08-01",
                        ),
                    ],
                    "edges" => [
                        Dict{String,Any}(
                            "source" => 1,
                            "target" => 2,
                            "probability" => 1.0,
                            "discount_rate" => 0.0,
                        ),
                    ],
                ),
            ),
            "inflow" => Dict{String,Any}(
                "stochastic_process" => Dict{String,Any}(
                    "kind" => "Naive",
                    "params" => Dict{String,Any}(
                        "marginal_models" => [
                            Dict{String,Any}(
                                "id" => 1,
                                "distributions" => [
                                    Dict{String,Any}(
                                        "season" => 1,
                                        "kind" => "Normal",
                                        "parameters" => [70.0, 7.0],
                                    ),
                                    Dict{String,Any}(
                                        "season" => 2,
                                        "kind" => "Normal",
                                        "parameters" => [70.0, 7.0],
                                    ),
                                ],
                            ),
                        ],
                        "copulas" => [
                            Dict{String,Any}(
                                "season" => 1,
                                "kind" => "GaussianCopula",
                                "parameters" => [[1.0]],
                            ),
                            Dict{String,Any}(
                                "season" => 2,
                                "kind" => "GaussianCopula",
                                "parameters" => [[1.0]],
                            ),
                        ],
                    ),
                ),
            ),
            "load" => Dict{String,Any}(
                "kind" => "DeterministicLoad",
                "params" => Dict{String,Any}(
                    "values" => [
                        Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0),
                        Dict{String,Any}("bus_id" => 1, "node_id" => 2, "value" => 100.0),
                    ],
                ),
            ),
            # Stage 1 duration is 720h (June), but blocks sum to 600h -- should fail
            "stage_blocks" => Dict{String,Any}(
                "1" => Dict{String,Any}(
                    "mode" => "parallel",
                    "definitions" => [
                        Dict{String,Any}("name" => "peak", "duration_hours" => 300.0),
                        Dict{String,Any}("name" => "offpeak", "duration_hours" => 300.0),
                    ],
                ),
            ),
        )

        e = CompositeException()
        sd = Scenarios.ScenariosData(base_d, e)
        @test sd === nothing
        @test length(e) >= 1
        # Error message should mention the stage and duration mismatch
        error_msgs = [string(err) for err in e.exceptions]
        @test any(contains(msg, "Stage 1") for msg in error_msgs)
    end

    # ---------------------------------------------------------------------------------
    # 11. Mixed parallel/chronological modes across stages: block weight correctness
    # ---------------------------------------------------------------------------------
    @testset "per-stage-block-weights" begin
        # Stage 1: parallel blocks [6h, 18h], Stage 2: chronological blocks [8h, 8h, 8h]
        bc1 = Scenarios.BlockConfig(
            :parallel, [Scenarios.Block("peak", 6.0), Scenarios.Block("offpeak", 18.0)]
        )
        bc2 = Scenarios.BlockConfig(
            :chronological,
            [
                Scenarios.Block("b1", 8.0),
                Scenarios.Block("b2", 8.0),
                Scenarios.Block("b3", 8.0),
            ],
        )

        tau1 = 24.0
        tau2 = 24.0

        durations1 = Scenarios.get_block_durations(bc1, tau1)
        weights1 = Scenarios.get_block_weights(durations1)
        @test durations1 == [6.0, 18.0]
        @test weights1[1] ≈ 6.0 / 24.0
        @test weights1[2] ≈ 18.0 / 24.0
        @test sum(weights1) ≈ 1.0

        durations2 = Scenarios.get_block_durations(bc2, tau2)
        weights2 = Scenarios.get_block_weights(durations2)
        @test durations2 == [8.0, 8.0, 8.0]
        @test all(w ≈ 1.0 / 3.0 for w in weights2)
        @test sum(weights2) ≈ 1.0
    end
end
