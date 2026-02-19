import SDDPlab: Scenarios
import SDDPlab: StochasticProcess
import SDDPlab: Engines
import SDDPlab: Lab
import SDDPlab: Utils

using Dates
using SDDP: SDDP
using JuMP

# ===================================================================
# Test data helpers
# ===================================================================

function _make_naive_dict()
    return Dict{String,Any}(
        "marginal_models" => [
            Dict{String,Any}(
                "id" => 1,
                "distributions" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "kind" => "Normal",
                        "parameters" => [70.0, 7.0],
                    ),
                ],
            ),
        ],
        "copulas" => [
            Dict{String,Any}(
                "season" => 1, "kind" => "GaussianCopula", "parameters" => [[1.0]]
            ),
        ],
    )
end

function _make_ar_dict(mean::Float64, std::Float64)
    return Dict{String,Any}(
        "kind" => "AutoRegressive",
        "params" => Dict{String,Any}(
            "marginal_models" => [
                Dict{String,Any}(
                    "id" => 1,
                    "initial_values" => [mean],
                    "models" => [
                        Dict{String,Any}(
                            "season" => 1,
                            "coefficients" => [0.5],
                            "scale_parameters" => [mean, std],
                            "residual_variance" => 1.0,
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
            ],
        ),
    )
end

function _make_graph_dict(num_stages::Int)
    nodes = []
    for i in 1:num_stages
        push!(
            nodes,
            Dict{String,Any}(
                "id" => i,
                "stage" => i,
                "start_datetime" => "2024-0$(i)-01",
                "end_datetime" => "2024-0$(i + 1)-01",
            ),
        )
    end
    edges = []
    for i in 1:(num_stages - 1)
        push!(
            edges,
            Dict{String,Any}(
                "source" => i,
                "target" => i + 1,
                "probability" => 1.0,
                "discount_rate" => 0.0,
            ),
        )
    end
    return Dict{String,Any}(
        "params" => Dict{String,Any}("nodes" => nodes, "edges" => edges)
    )
end

function _make_load_dict(num_stages::Int)
    values = []
    for i in 1:num_stages
        push!(values, Dict{String,Any}("bus_id" => 1, "node_id" => i, "value" => 100.0))
    end
    return Dict{String,Any}(
        "kind" => "DeterministicLoad", "params" => Dict{String,Any}("values" => values)
    )
end

function _make_markov_chain_dict_2states()
    return Dict{String,Any}(
        "transition_matrices" => [
            [[0.5, 0.5]],                    # Stage 1: root -> 2 states (1x2)
            [[0.8, 0.2], [0.3, 0.7]],       # Stage 2: 2x2 transition
            [[0.8, 0.2], [0.3, 0.7]],       # Stage 3: 2x2 transition
        ],
    )
end

function _make_scenarios_dict_with_markov()
    return Dict{String,Any}(
        "seed" => 42,
        "initial_season" => 1,
        "branchings" => 10,
        "graph" => _make_graph_dict(3),
        "markov_chain" => _make_markov_chain_dict_2states(),
        "inflow" => Dict{String,Any}(
            "stochastic_process" => Dict{String,Any}(
                "1" => _make_ar_dict(40.0, 10.0), "2" => _make_ar_dict(80.0, 20.0)
            ),
        ),
        "load" => _make_load_dict(3),
    )
end

function _make_scenarios_dict_without_markov()
    return Dict{String,Any}(
        "seed" => 42,
        "initial_season" => 1,
        "branchings" => 10,
        "graph" => _make_graph_dict(2),
        "inflow" => Dict{String,Any}(
            "stochastic_process" =>
                Dict{String,Any}("kind" => "Naive", "params" => _make_naive_dict()),
        ),
        "load" => _make_load_dict(2),
    )
end

# ===================================================================
# Tests
# ===================================================================

@testset "markov-chain" begin

    # ---------------------------------------------------------------
    # MarkovChainConfig constructor
    # ---------------------------------------------------------------
    @testset "markov-config-valid-2-states" begin
        d = deepcopy(_make_markov_chain_dict_2states())
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc !== nothing
        @test length(e) == 0
        @test mc.num_states == 2
        @test length(mc.transition_matrices) == 3  # 3 stages
        @test size(mc.transition_matrices[1]) == (1, 2)
        @test size(mc.transition_matrices[2]) == (2, 2)
        @test size(mc.transition_matrices[3]) == (2, 2)
        @test Scenarios.has_markov_chain(mc) == true
        @test Scenarios.num_markov_states(mc) == 2
    end

    @testset "markov-config-valid-3-states" begin
        d = Dict{String,Any}(
            "transition_matrices" => [
                [[1.0 / 3, 1.0 / 3, 1.0 / 3]],
                [[0.5, 0.3, 0.2], [0.2, 0.5, 0.3], [0.3, 0.3, 0.4]],
            ],
        )
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc !== nothing
        @test mc.num_states == 3
    end

    @testset "markov-config-invalid-first-row-not-1" begin
        d = Dict{String,Any}(
            "transition_matrices" => [
                [[0.5, 0.5], [0.3, 0.7]],  # 2 rows, should be 1
                [[0.8, 0.2], [0.3, 0.7]],
            ]
        )
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    @testset "markov-config-invalid-dimension-mismatch" begin
        d = Dict{String,Any}(
            "transition_matrices" => [
                [[0.5, 0.5]],                      # 1x2
                [[0.8, 0.1, 0.1], [0.3, 0.5, 0.2], [0.1, 0.2, 0.7]],  # 3x3, should be 2x2
            ],
        )
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    @testset "markov-config-invalid-row-sum" begin
        d = Dict{String,Any}(
            "transition_matrices" => [
                [[0.4, 0.4]],               # sums to 0.8, not 1.0
                [[0.8, 0.2], [0.3, 0.7]],
            ]
        )
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    @testset "markov-config-invalid-negative-entry" begin
        d = Dict{String,Any}(
            "transition_matrices" => [[[0.5, 0.5]], [[1.2, -0.2], [0.3, 0.7]]]
        )
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    @testset "markov-config-empty-matrices" begin
        d = Dict{String,Any}("transition_matrices" => [])
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    @testset "markov-config-missing-key" begin
        d = Dict{String,Any}()
        e = CompositeException()
        mc = Scenarios.MarkovChainConfig(d, e)
        @test mc === nothing
        @test length(e) > 0
    end

    # ---------------------------------------------------------------
    # NoMarkovChain sentinel
    # ---------------------------------------------------------------
    @testset "no-markov-chain-sentinel" begin
        mc = Scenarios.NoMarkovChain()
        @test Scenarios.has_markov_chain(mc) == false
        @test Scenarios.num_markov_states(mc) == 1
    end

    # ---------------------------------------------------------------
    # InflowScenarios with multi-process (Markov format)
    # ---------------------------------------------------------------
    @testset "inflow-multi-process-dict-of-dicts" begin
        d = Dict{String,Any}(
            "stochastic_process" => Dict{String,Any}(
                "1" => _make_ar_dict(40.0, 10.0), "2" => _make_ar_dict(80.0, 20.0)
            ),
        )
        e = CompositeException()
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow !== nothing
        @test length(e) == 0
        @test length(inflow.stochastic_process) == 2
        @test haskey(inflow.stochastic_process, 1)
        @test haskey(inflow.stochastic_process, 2)
        @test Scenarios.get_stochastic_process(inflow, 1) isa
            StochasticProcess.AutoRegressive
        @test Scenarios.get_stochastic_process(inflow, 2) isa
            StochasticProcess.AutoRegressive
    end

    @testset "inflow-single-process-legacy-format" begin
        d = Dict{String,Any}(
            "stochastic_process" =>
                Dict{String,Any}("kind" => "Naive", "params" => _make_naive_dict()),
        )
        e = CompositeException()
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow !== nothing
        @test length(e) == 0
        @test length(inflow.stochastic_process) == 1
        @test haskey(inflow.stochastic_process, 1)
        @test Scenarios.get_stochastic_process(inflow) isa StochasticProcess.Naive
    end

    @testset "inflow-multi-process-invalid-key" begin
        d = Dict{String,Any}(
            "stochastic_process" => Dict{String,Any}(
                "dry" => _make_ar_dict(40.0, 10.0), "wet" => _make_ar_dict(80.0, 20.0)
            ),
        )
        e = CompositeException()
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow === nothing
        @test length(e) > 0
    end

    # ---------------------------------------------------------------
    # ScenariosData with Markov chain
    # ---------------------------------------------------------------
    @testset "scenariosdata-with-markov-valid" begin
        d = _make_scenarios_dict_with_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing
        @test length(e) == 0
        @test Scenarios.has_markov_chain(s.markov_chain)
        @test Scenarios.num_markov_states(s.markov_chain) == 2
        @test length(s.inflow.stochastic_process) == 2
    end

    @testset "scenariosdata-without-markov-backward-compat" begin
        d = _make_scenarios_dict_without_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing
        @test length(e) == 0
        @test !Scenarios.has_markov_chain(s.markov_chain)
        @test s.markov_chain isa Scenarios.NoMarkovChain
        @test length(s.inflow.stochastic_process) == 1
    end

    @testset "scenariosdata-markov-process-count-mismatch" begin
        d = _make_scenarios_dict_with_markov()
        # Remove one stochastic process, leaving only 1 for 2 Markov states
        delete!(d["inflow"]["stochastic_process"], "2")
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s === nothing
        @test length(e) > 0
    end

    @testset "scenariosdata-markov-invalid-transition-matrices" begin
        d = _make_scenarios_dict_with_markov()
        d["markov_chain"]["transition_matrices"] = [
            [[0.5, 0.5]],
            [[0.9, 0.2], [0.3, 0.7]],  # row 1 sums to 1.1
        ]
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s === nothing
        @test length(e) > 0
    end

    # ---------------------------------------------------------------
    # Graph building: legacy vs Markov
    # ---------------------------------------------------------------
    @testset "build-graph-legacy-integer-nodes" begin
        d = _make_scenarios_dict_without_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing
        files = Lab.InputModule[s]

        graph = Engines.__build_graph(files)
        @test graph isa SDDP.Graph{Int}
    end

    @testset "build-graph-markov-tuple-nodes" begin
        d = _make_scenarios_dict_with_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing
        files = Lab.InputModule[s]

        graph = Engines.__build_graph(files)
        @test graph isa SDDP.Graph{Tuple{Int64,Int64}}
    end

    # ---------------------------------------------------------------
    # SAA generation per Markov state
    # ---------------------------------------------------------------
    @testset "saa-per-markov-state" begin
        d = _make_scenarios_dict_with_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing

        saa = Engines.generate_saa(s, 3, 42)
        @test saa isa Dict{Int,Vector{Vector{Vector{Float64}}}}
        @test haskey(saa, 1)
        @test haskey(saa, 2)
        @test length(saa[1]) == 3  # 3 stages
        @test length(saa[2]) == 3

        # Different states should produce different SAA (different seed offsets)
        @test saa[1] != saa[2]
    end

    @testset "saa-legacy-single-state" begin
        d = _make_scenarios_dict_without_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing

        saa = Engines.generate_saa(s, 2, 42)
        @test saa isa Dict{Int,Vector{Vector{Vector{Float64}}}}
        @test haskey(saa, 1)
        @test length(saa) == 1  # only state 1
        @test length(saa[1]) == 2  # 2 stages
    end

    # ---------------------------------------------------------------
    # Subproblem builder with MarkovianGraph
    # ---------------------------------------------------------------
    @testset "subproblem-builder-markov-different-ar-params" begin
        d = _make_scenarios_dict_with_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing

        # Build a minimal system using the same pattern as test-systemdata.jl
        system_d = convert(
            Dict{String,Any},
            Dict(
                "buses" => Dict{String,Any}(
                    "entities" => [
                        Dict{String,Any}(
                            "id" => 1, "name" => "bus1", "deficit_cost" => 1000.0
                        ),
                    ],
                ),
                "lines" => Dict{String,Any}("entities" => Any[]),
                "thermals" => Dict{String,Any}("entities" => Any[]),
                "hydros" => Dict{String,Any}(
                    "entities" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "name" => "hydro1",
                            "bus_id" => 1,
                            "downstream_id" => 0,
                            "productivity" => 1.0,
                            "initial_storage" => 50.0,
                            "min_storage" => 0.0,
                            "max_storage" => 100.0,
                            "min_generation" => 0.0,
                            "max_generation" => 50.0,
                            "spillage_penalty" => 0.001,
                        ),
                    ],
                ),
            ),
        )

        system_e = CompositeException()
        system = SDDPlab.System.SystemData(system_d, system_e)
        @test system !== nothing

        files = Lab.InputModule[s, system]

        using HiGHS: HiGHS
        scaling = Engines.ScalingConfig(Dict{Symbol,Float64}())
        method = Engines.InflowNone()

        # Build the SDDP model
        graph = Engines.__build_graph(files)
        @test graph isa SDDP.Graph{Tuple{Int64,Int64}}

        sp_builder = Engines.__generate_subproblem_builder(files, scaling, method)

        model = SDDP.PolicyGraph(
            sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = HiGHS.Optimizer
        )

        # Verify model was created with tuple nodes
        @test model isa SDDP.PolicyGraph{Tuple{Int64,Int64}}

        # Verify the model has the expected number of nodes:
        # Stage 1: 2 nodes (state 1, state 2)
        # Stage 2: 2 nodes (state 1, state 2)
        # Stage 3: 2 nodes (state 1, state 2)
        # Total = 6 non-root nodes
        node_keys = collect(keys(model.nodes))
        @test length(node_keys) == 6

        # Verify all stages are represented
        stages = unique([k[1] for k in node_keys])
        @test sort(stages) == [1, 2, 3]

        # Verify all markov states are represented at each stage
        for stage in stages
            states_at_stage = [k[2] for k in node_keys if k[1] == stage]
            @test sort(states_at_stage) == [1, 2]
        end
    end

    # ---------------------------------------------------------------
    # Verify AR params differ between Markov states
    # ---------------------------------------------------------------
    @testset "markov-regime-specific-ar-constraints" begin
        d = _make_scenarios_dict_with_markov()
        e = CompositeException()
        s = Scenarios.ScenariosData(d, e)
        @test s !== nothing

        # Verify the two stochastic processes have different scale parameters
        p1 = Scenarios.get_stochastic_process(s.inflow, 1)
        p2 = Scenarios.get_stochastic_process(s.inflow, 2)

        scale1 = StochasticProcess.get_ar_scale(p1, 1)
        scale2 = StochasticProcess.get_ar_scale(p2, 1)

        # Process 1: mean=40.0, std=10.0
        # Process 2: mean=80.0, std=20.0
        @test scale1[1][1] == 40.0
        @test scale1[1][2] == 10.0
        @test scale2[1][1] == 80.0
        @test scale2[1][2] == 20.0
    end

    # ---------------------------------------------------------------
    # Extract stage/markov_state helpers
    # ---------------------------------------------------------------
    @testset "extract-stage-integer" begin
        @test Engines.__extract_stage(5) == 5
        @test Engines.__extract_markov_state(5) == 1
    end

    @testset "extract-stage-tuple" begin
        @test Engines.__extract_stage((3, 2)) == 3
        @test Engines.__extract_markov_state((3, 2)) == 2
    end

    # ---------------------------------------------------------------
    # VectorAutoRegressive with Markov states
    # ---------------------------------------------------------------
    @testset "markov-with-var-processes" begin
        function _make_var_dict(scale_mean::Float64, scale_std::Float64)
            return Dict{String,Any}(
                "kind" => "VectorAutoRegressive",
                "params" => Dict{String,Any}(
                    "marginal_models" => [
                        Dict{String,Any}(
                            "id" => 1,
                            "initial_values" => [scale_mean],
                            "models" => [
                                Dict{String,Any}(
                                    "season" => 1,
                                    "scale_parameters" => [scale_mean, scale_std],
                                    "residual_variance" => 1.0,
                                ),
                            ],
                        ),
                    ],
                    "coefficient_matrices" => [
                        Dict{String,Any}("season" => 1, "lag" => 1, "matrix" => [[0.5]]),
                    ],
                    "copulas" => [
                        Dict{String,Any}(
                            "season" => 1,
                            "kind" => "GaussianCopula",
                            "parameters" => [[1.0]],
                        ),
                    ],
                ),
            )
        end

        d = Dict{String,Any}(
            "stochastic_process" => Dict{String,Any}(
                "1" => _make_var_dict(40.0, 10.0), "2" => _make_var_dict(80.0, 20.0)
            ),
        )
        e = CompositeException()
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow !== nothing
        @test length(e) == 0
        @test Scenarios.get_stochastic_process(inflow, 1) isa
            StochasticProcess.VectorAutoRegressive
        @test Scenarios.get_stochastic_process(inflow, 2) isa
            StochasticProcess.VectorAutoRegressive

        # Verify different regime parameters
        p1 = Scenarios.get_stochastic_process(inflow, 1)
        p2 = Scenarios.get_stochastic_process(inflow, 2)
        @test StochasticProcess.get_var_scales(p1, 1)[1][1] == 40.0
        @test StochasticProcess.get_var_scales(p2, 1)[1][1] == 80.0
    end
end
