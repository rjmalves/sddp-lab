import SDDPlab: Scenarios

using Dates
using Test

# =====================================================================================
# Helpers
# =====================================================================================

"""
Build a minimal two-stage Graph for use in block-config parsing tests.
Stage 1: node id=1 (June = 30 days = 720h), Stage 2: node id=2 (July 1-31 = 30 days = 720h).
Both stages have equal duration (720h) so global block configs can be tested.
"""
function _make_two_stage_graph_dict()
    return Dict{String,Any}(
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
                    "end_datetime" => "2024-07-31",
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
    )
end

"""
Build a minimal ScenariosData dict (without 'blocks' / 'stage_blocks') for testing.
Callers can add block keys as needed.
"""
function _make_scenarios_base_dict()
    naive_inflow_dict = Dict{String,Any}(
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

    inflow_dict = Dict{String,Any}(
        "stochastic_process" =>
            Dict{String,Any}("kind" => "Naive", "params" => naive_inflow_dict),
    )

    load_dict = Dict{String,Any}(
        "kind" => "DeterministicLoad",
        "params" => Dict{String,Any}(
            "values" => [
                Dict{String,Any}("bus_id" => 1, "node_id" => 1, "value" => 100.0),
                Dict{String,Any}("bus_id" => 1, "node_id" => 2, "value" => 100.0),
            ],
        ),
    )

    return Dict{String,Any}(
        "seed" => 42,
        "initial_season" => 1,
        "branchings" => 1,
        "graph" => _make_two_stage_graph_dict(),
        "inflow" => inflow_dict,
        "load" => load_dict,
    )
end

"""
720h = 30 days, matching both stages in _make_two_stage_graph_dict()
"""
function _parallel_blocks_dict()
    return Dict{String,Any}(
        "mode" => "parallel",
        "definitions" => [
            Dict{String,Any}("name" => "peak", "duration_hours" => 240.0),
            Dict{String,Any}("name" => "offpeak", "duration_hours" => 480.0),
        ],
    )
end

"""
720h = 30 days, matching both stages in _make_two_stage_graph_dict()
"""
function _chronological_blocks_dict()
    return Dict{String,Any}(
        "mode" => "chronological",
        "definitions" => [
            Dict{String,Any}("name" => "b1", "duration_hours" => 240.0),
            Dict{String,Any}("name" => "b2", "duration_hours" => 240.0),
            Dict{String,Any}("name" => "b3", "duration_hours" => 240.0),
        ],
    )
end

# =====================================================================================
# Tests for __build_block_config! via ScenariosData parsing
# =====================================================================================

@testset "per-stage-block-configs" begin

    # ---------------------------------------------------------------------------------
    # 1. Neither key present: empty dict, get_block_config returns default for any stage
    # ---------------------------------------------------------------------------------
    @testset "no-blocks-key-yields-empty-dict" begin
        d = _make_scenarios_base_dict()
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test scenarios !== nothing
        @test scenarios.block_configs isa Dict{Int,Scenarios.BlockConfig}
        @test isempty(scenarios.block_configs)

        # Fallback to default for any stage
        bc1 = Scenarios.get_block_config(scenarios, 1)
        bc2 = Scenarios.get_block_config(scenarios, 2)
        bc99 = Scenarios.get_block_config(scenarios, 99)
        @test Scenarios.has_blocks(bc1) == false
        @test Scenarios.has_blocks(bc2) == false
        @test Scenarios.has_blocks(bc99) == false
        @test Scenarios.num_blocks(bc1) == 1
    end

    # ---------------------------------------------------------------------------------
    # 2. Legacy 'blocks' key: same BlockConfig applied to all stages, @warn emitted
    # ---------------------------------------------------------------------------------
    @testset "legacy-blocks-key-applies-to-all-stages-with-warn" begin
        d = _make_scenarios_base_dict()
        d["blocks"] = _parallel_blocks_dict()
        e = CompositeException()

        # The legacy path emits a @warn deprecation -- check it fires
        scenarios = @test_logs (:warn, r"deprecated") Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test scenarios !== nothing
        @test scenarios.block_configs isa Dict{Int,Scenarios.BlockConfig}

        # Both stages in the two-stage graph must have entries
        @test haskey(scenarios.block_configs, 1)
        @test haskey(scenarios.block_configs, 2)

        bc1 = Scenarios.get_block_config(scenarios, 1)
        bc2 = Scenarios.get_block_config(scenarios, 2)
        @test bc1.mode == :parallel
        @test bc2.mode == :parallel
        @test length(bc1.blocks) == 2
        @test length(bc2.blocks) == 2
        @test bc1.blocks[1].name == "peak"
        @test bc2.blocks[1].name == "peak"
    end

    # ---------------------------------------------------------------------------------
    # 3. New per-stage 'stage_blocks' key: each stage gets its own BlockConfig
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-per-stage-parsing" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => _parallel_blocks_dict(), "2" => _chronological_blocks_dict()
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test scenarios !== nothing

        bc1 = Scenarios.get_block_config(scenarios, 1)
        bc2 = Scenarios.get_block_config(scenarios, 2)

        @test bc1.mode == :parallel
        @test length(bc1.blocks) == 2
        @test bc1.blocks[1].name == "peak"

        @test bc2.mode == :chronological
        @test length(bc2.blocks) == 3
        @test bc2.blocks[1].name == "b1"
    end

    # ---------------------------------------------------------------------------------
    # 4. stage_blocks with a stage not in graph: @warn emitted, entry still parsed
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-unknown-stage-warns" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => _parallel_blocks_dict(),
            "99" => _parallel_blocks_dict(),  # stage 99 not in graph
        )
        e = CompositeException()

        # Should warn about stage 99 not in graph
        scenarios = @test_logs (:warn, r"99") Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test scenarios !== nothing
        # Stage 1 parsed correctly
        bc1 = Scenarios.get_block_config(scenarios, 1)
        @test bc1.mode == :parallel
        # Stage 2 not specified -> default
        bc2 = Scenarios.get_block_config(scenarios, 2)
        @test Scenarios.has_blocks(bc2) == false
    end

    # ---------------------------------------------------------------------------------
    # 5. Both 'blocks' and 'stage_blocks' present: error in CompositeException
    # ---------------------------------------------------------------------------------
    @testset "both-keys-present-yields-error" begin
        d = _make_scenarios_base_dict()
        d["blocks"] = _parallel_blocks_dict()
        d["stage_blocks"] = Dict{String,Any}("1" => _parallel_blocks_dict())
        e = CompositeException()

        # Suppress the deprecation warn path (not reached, but safety net)
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios === nothing
        @test length(e) >= 1
        error_msgs = [string(ex) for ex in e.exceptions]
        @test any(
            msg -> occursin("blocks", msg) && occursin("stage_blocks", msg), error_msgs
        )
    end

    # ---------------------------------------------------------------------------------
    # 6. stage_blocks with non-integer key: error in CompositeException
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-non-integer-key-yields-error" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}("abc" => _parallel_blocks_dict())
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios === nothing
        @test length(e) >= 1
        error_msgs = [string(ex) for ex in e.exceptions]
        @test any(msg -> occursin("abc", msg), error_msgs)
    end

    # ---------------------------------------------------------------------------------
    # 7. get_block_config(scenarios, stage) returns correct config for explicit stage
    # ---------------------------------------------------------------------------------
    @testset "get-block-config-returns-correct-per-stage" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => _parallel_blocks_dict(), "2" => _chronological_blocks_dict()
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios !== nothing

        bc1 = Scenarios.get_block_config(scenarios, 1)
        @test bc1.mode == :parallel
        @test Scenarios.num_blocks(bc1) == 2
        @test Scenarios.get_block_names(bc1) == ["peak", "offpeak"]

        bc2 = Scenarios.get_block_config(scenarios, 2)
        @test bc2.mode == :chronological
        @test Scenarios.num_blocks(bc2) == 3
        @test Scenarios.get_block_names(bc2) == ["b1", "b2", "b3"]
    end

    # ---------------------------------------------------------------------------------
    # 8. get_block_config(scenarios, stage) returns default when stage absent
    # ---------------------------------------------------------------------------------
    @testset "get-block-config-returns-default-for-absent-stage" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => _parallel_blocks_dict(),
            # stage 2 not specified
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios !== nothing

        bc2 = Scenarios.get_block_config(scenarios, 2)
        default = Scenarios.default_block_config()
        @test bc2.mode == default.mode
        @test Scenarios.has_blocks(bc2) == false
        @test Scenarios.num_blocks(bc2) == 1
    end

    # ---------------------------------------------------------------------------------
    # 9. Integration: full ScenariosData construction with 'stage_blocks'
    # ---------------------------------------------------------------------------------
    @testset "integration-full-construction-stage-blocks" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => _parallel_blocks_dict(), "2" => _chronological_blocks_dict()
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test typeof(scenarios) === Scenarios.ScenariosData
        @test scenarios.block_configs isa Dict{Int,Scenarios.BlockConfig}
        @test length(scenarios.block_configs) == 2
        @test haskey(scenarios.block_configs, 1)
        @test haskey(scenarios.block_configs, 2)
    end

    # ---------------------------------------------------------------------------------
    # 10. Integration: full ScenariosData construction with legacy 'blocks' (compat)
    # ---------------------------------------------------------------------------------
    @testset "integration-full-construction-legacy-blocks" begin
        d = _make_scenarios_base_dict()
        d["blocks"] = _parallel_blocks_dict()
        e = CompositeException()
        scenarios = @test_logs (:warn, r"deprecated") Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test typeof(scenarios) === Scenarios.ScenariosData
        # Two-stage graph -> two entries in the dict
        @test length(scenarios.block_configs) == 2
        @test Scenarios.get_block_config(scenarios, 1).mode == :parallel
        @test Scenarios.get_block_config(scenarios, 2).mode == :parallel
    end

    # ---------------------------------------------------------------------------------
    # 11. Block duration sum mismatch: hard validation error
    # ---------------------------------------------------------------------------------
    @testset "block-duration-sum-mismatch-is-hard-error" begin
        d = _make_scenarios_base_dict()
        # Blocks sum to 24h but stage is 720h — should be rejected
        d["stage_blocks"] = Dict{String,Any}(
            "1" => Dict{String,Any}(
                "mode" => "parallel",
                "definitions" => [
                    Dict{String,Any}("name" => "peak", "duration_hours" => 8.0),
                    Dict{String,Any}("name" => "offpeak", "duration_hours" => 16.0),
                ],
            ),
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios === nothing
        @test length(e) >= 1
        error_msgs = [string(ex) for ex in e.exceptions]
        @test any(msg -> occursin("block durations sum to", msg), error_msgs)
        @test any(msg -> occursin("Stage 1", msg), error_msgs)
    end

    # ---------------------------------------------------------------------------------
    # 12. Block duration sum match: validation passes
    # ---------------------------------------------------------------------------------
    @testset "block-duration-sum-match-passes-validation" begin
        d = _make_scenarios_base_dict()
        # 240 + 480 = 720h matches the stage duration
        d["stage_blocks"] = Dict{String,Any}("1" => _parallel_blocks_dict())
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test length(e) == 0
        @test scenarios !== nothing
    end

    # ---------------------------------------------------------------------------------
    # 13. Invalid BlockConfig inside stage_blocks propagates errors
    # ---------------------------------------------------------------------------------
    @testset "stage-blocks-invalid-blockconfig-propagates-error" begin
        d = _make_scenarios_base_dict()
        d["stage_blocks"] = Dict{String,Any}(
            "1" => Dict{String,Any}(
                "mode" => "invalid_mode",
                "definitions" =>
                    [Dict{String,Any}("name" => "b1", "duration_hours" => 8.0)],
            ),
        )
        e = CompositeException()
        scenarios = Scenarios.ScenariosData(d, e)
        @test scenarios === nothing
        @test length(e) >= 1
    end
end
