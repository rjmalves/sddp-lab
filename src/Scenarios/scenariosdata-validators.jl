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
    "block_config",
    "markov_chain",
]
UNCERTAINTIES_KEY_TYPES = [
    Integer,
    Integer,
    Integer,
    Graph,
    T where {T<:InflowScenarios},
    T where {T<:LoadScenarios},
    BlockConfig,
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
    if haskey(d, "blocks")
        blocks_d = d["blocks"]
        if !(blocks_d isa Dict)
            push!(e, AssertionError("'blocks' must be a Dict, got $(typeof(blocks_d))"))
            d["block_config"] = default_block_config()
            return false
        end
        bc = BlockConfig(blocks_d, e)
        if bc === nothing
            d["block_config"] = default_block_config()
            return false
        end
        d["block_config"] = bc
    else
        d["block_config"] = default_block_config()
    end
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
