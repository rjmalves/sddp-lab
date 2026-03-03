const SCENARIOS_DATA_SCHEMA = [
    FieldRule("seed", Integer),
    FieldRule("initial_season", Integer; constraints = [positive()]),
    FieldRule("branchings", Integer; constraints = [positive()]),
]

UNCERTAINTIES_KEYS = [
    "seed",
    "initial_season",
    "branchings",
    "graph",
    "inflow",
    "load",
    "block_configs",
    "markov_chain",
]
UNCERTAINTIES_KEY_TYPES = [
    Integer,
    Integer,
    Integer,
    Graph,
    T where {T<:InflowScenarios},
    T where {T<:LoadScenarios},
    Dict{Int,BlockConfig},
    T where {T<:AbstractMarkovChain},
]
UNCERTAINTIES_KEY_TYPES_BEFORE_BUILD = [
    Integer, Integer, Integer, Dict{String,Any}, Dict{String,Any}, Dict{String,Any}
]

function __validate_scenarios_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = UNCERTAINTIES_KEYS
    keys_types = UNCERTAINTIES_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_scenarios_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["seed", "initial_season", "branchings", "graph", "inflow", "load"]
    keys_types = UNCERTAINTIES_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_deterministic_load_node_references!(
    load::DeterministicLoad, graph::Graph, e::CompositeException
)::Bool
    graph_node_ids = Set([n.id for n in graph.nodes])
    root_node_id = get_root_node_id(graph)
    non_root_node_ids = setdiff(graph_node_ids, Set([root_node_id]))

    valid = true

    for v in load.values
        if !(v.node_id in graph_node_ids)
            push!(e, AssertionError("Load node_id ($(v.node_id)) not found in graph"))
            valid = false
        end
    end

    load_bus_ids = Set([v.bus_id for v in load.values])
    for node_id in non_root_node_ids
        for bus_id in load_bus_ids
            has_entry = any(v -> v.bus_id == bus_id && v.node_id == node_id, load.values)
            if !has_entry
                @warn "No load value for bus_id=$bus_id at graph node_id=$node_id, will default to 0.0"
            end
        end
    end

    return valid
end

function __validate_block_duration_sums!(
    block_configs::Dict{Int,BlockConfig}, graph::Graph, e::CompositeException
)::Bool
    valid = true
    stage_taus = Dict{Int,Float64}()
    for node in graph.nodes
        if !haskey(stage_taus, node.stage)
            tau =
                Float64(Dates.value(node.end_datetime - node.start_datetime)) / 3_600_000.0
            stage_taus[node.stage] = tau
        end
    end

    for (stage, bc) in block_configs
        if !has_blocks(bc)
            continue
        end
        if !haskey(stage_taus, stage)
            continue
        end
        tau = stage_taus[stage]
        block_sum = sum(b.duration_hours for b in bc.blocks)
        if abs(block_sum - tau) > 1e-3
            push!(
                e,
                ErrorException(
                    "Stage $stage: block durations sum to $block_sum hours " *
                    "but stage duration is $tau hours (from graph datetimes). " *
                    "Block durations must equal the stage duration.",
                ),
            )
            valid = false
        end
    end

    return valid
end

function __validate_scenarios_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid = true
    load = d["load"]
    graph = d["graph"]
    if load isa DeterministicLoad
        valid = valid && __validate_deterministic_load_node_references!(load, graph, e)
    end

    # Validate Markov chain / stochastic process consistency
    mc = d["markov_chain"]
    inflow = d["inflow"]
    if has_markov_chain(mc)
        valid = valid && __validate_markov_process_consistency!(mc, inflow, e)
    end

    # Validate block duration sums match stage durations
    block_configs = d["block_configs"]
    valid = valid && __validate_block_duration_sums!(block_configs, graph, e)

    return valid
end

"""
    __validate_markov_process_consistency!(mc, inflow, e) -> Bool

Validate that the number of Markov states matches the number of stochastic processes
in the InflowScenarios.
"""
function __validate_markov_process_consistency!(
    mc::MarkovChainConfig, inflow::InflowScenarios, e::CompositeException
)::Bool
    n_mc_states = num_markov_states(mc)
    n_processes = length(inflow.stochastic_process)
    process_keys = sort(collect(keys(inflow.stochastic_process)))

    valid = true

    if n_processes != n_mc_states
        push!(
            e,
            AssertionError(
                "Markov chain has $n_mc_states states but stochastic_process has $n_processes entries (must match)",
            ),
        )
        valid = false
    end

    # Check that process keys are exactly 1:n_mc_states
    expected_keys = collect(1:n_mc_states)
    if process_keys != expected_keys
        push!(
            e,
            AssertionError(
                "Markov stochastic_process keys must be $(expected_keys), got $(process_keys)",
            ),
        )
        valid = false
    end

    return valid
end

function __build_block_config!(d::Dict{String,Any}, e::CompositeException)::Bool
    has_legacy = haskey(d, "blocks")
    has_per_stage = haskey(d, "stage_blocks")

    # Mutual exclusion: cannot specify both formats simultaneously
    if has_legacy && has_per_stage
        push!(
            e,
            ErrorException(
                "Cannot specify both 'blocks' and 'stage_blocks' in scenarios config"
            ),
        )
        d["block_configs"] = Dict{Int,BlockConfig}()
        return false
    end

    if has_legacy
        # Legacy global format: apply the same BlockConfig to all stages in the graph.
        # Emit a deprecation warning.
        @warn "The 'blocks' key in scenarios config is deprecated. " *
            "Use 'stage_blocks' with per-stage keys instead."

        blocks_d = d["blocks"]
        if !(blocks_d isa Dict)
            push!(e, AssertionError("'blocks' must be a Dict, got $(typeof(blocks_d))"))
            d["block_configs"] = Dict{Int,BlockConfig}()
            return false
        end

        bc = BlockConfig(blocks_d, e)
        if bc === nothing
            d["block_configs"] = Dict{Int,BlockConfig}()
            return false
        end

        # Apply to all stages present in the already-parsed graph.
        # When called from the file-loading path the graph may not be parsed yet
        # (d["graph"] is still a raw Dict). In that case, store a singleton dict
        # keyed by 1; the second call through __build_scenarios_internals_from_dicts!
        # will have the parsed Graph and will spread the config correctly.
        graph = d["graph"]
        stage_indices = if graph isa Graph
            unique([n.stage for n in graph.nodes])
        else
            [1]
        end
        d["block_configs"] = Dict{Int,BlockConfig}(s => bc for s in stage_indices)
        return true
    end

    if has_per_stage
        # Per-stage format: parse each stage key individually
        stage_blocks_d = d["stage_blocks"]
        if !(stage_blocks_d isa Dict)
            push!(
                e,
                AssertionError(
                    "'stage_blocks' must be a Dict, got $(typeof(stage_blocks_d))"
                ),
            )
            d["block_configs"] = Dict{Int,BlockConfig}()
            return false
        end

        result = Dict{Int,BlockConfig}()
        valid = true

        # Collect graph stage indices for unknown-stage warning.
        # The graph may not yet be parsed into a Graph struct when __build_block_config!
        # is called during the file-loading path (__cast_scenarios_internals_from_files!),
        # so guard against accessing .nodes on a raw Dict.
        graph = d["graph"]
        graph_stages = if graph isa Graph
            Set([n.stage for n in graph.nodes])
        else
            Set{Int}()
        end

        for (key, value) in stage_blocks_d
            # Each key must be parseable as an integer
            stage_int = tryparse(Int, string(key))
            if stage_int === nothing
                push!(
                    e,
                    ErrorException(
                        "'stage_blocks' key '$key' is not a valid integer stage index"
                    ),
                )
                valid = false
                continue
            end

            # Warn if stage index not present in graph (but do not error)
            if !(stage_int in graph_stages)
                @warn "stage_blocks key $stage_int does not correspond to any stage in the graph and will be ignored"
            end

            if !(value isa Dict)
                push!(
                    e,
                    AssertionError(
                        "'stage_blocks' entry for stage $stage_int must be a Dict, " *
                        "got $(typeof(value))",
                    ),
                )
                valid = false
                continue
            end

            bc = BlockConfig(value, e)
            if bc === nothing
                valid = false
                continue
            end

            result[stage_int] = bc
        end

        d["block_configs"] = result
        return valid
    end

    # Neither key present: empty dict (getter returns default_block_config() on miss)
    d["block_configs"] = Dict{Int,BlockConfig}()
    return true
end

function __build_markov_chain!(d::Dict{String,Any}, e::CompositeException)::Bool
    if haskey(d, "markov_chain")
        mc_d = d["markov_chain"]
        if !(mc_d isa Dict{String,Any})
            push!(e, AssertionError("'markov_chain' must be a Dict, got $(typeof(mc_d))"))
            d["markov_chain"] = NoMarkovChain()
            return false
        end
        mc = MarkovChainConfig(mc_d, e)
        if mc === nothing
            d["markov_chain"] = NoMarkovChain()
            return false
        end
        d["markov_chain"] = mc
    else
        d["markov_chain"] = NoMarkovChain()
    end
    return true
end

function __build_scenarios_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_graph = __build_graph!(d, e)
    valid_markov = __build_markov_chain!(d, e)
    valid_inflow = __build_inflow_scenarios!(d, e)
    valid_load = __build_load_scenarios!(d, e)
    valid_blocks = __build_block_config!(d, e)
    return valid_graph && valid_markov && valid_inflow && valid_load && valid_blocks
end

function __cast_scenarios_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_scenarios_keys_types_before_build!(d, e)
    valid_graph = valid_key_types && __cast_graph_internals_from_files!(d, e)
    valid_inflow = valid_key_types && __cast_inflow_scenarios_internals_from_files!(d, e)
    valid_load = valid_key_types && __cast_load_scenarios_internals_from_files!(d, e)
    valid_blocks = __build_block_config!(d, e)
    return valid_graph && valid_inflow && valid_load && valid_blocks
end
