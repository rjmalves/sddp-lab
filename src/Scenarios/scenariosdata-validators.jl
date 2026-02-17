# SCHEMAS ----------------------------------------------------------------------------------

const SCENARIOS_DATA_SCHEMA = [
    FieldRule("seed", Integer),
    FieldRule("initial_season", Integer; constraints = [positive()]),
    FieldRule("branchings", Integer; constraints = [positive()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

UNCERTAINTIES_KEYS = ["seed", "initial_season", "branchings", "graph", "inflow", "load"]
UNCERTAINTIES_KEY_TYPES = [
    Integer,
    Integer,
    Integer,
    Graph,
    T where {T<:InflowScenarios},
    T where {T<:LoadScenarios},
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
    keys = UNCERTAINTIES_KEYS
    keys_types = UNCERTAINTIES_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_deterministic_load_node_references!(
    load::DeterministicLoad, graph::Graph, e::CompositeException
)::Bool
    graph_node_ids = Set([n.id for n in graph.nodes])
    root_node_id = get_root_node_id(graph)
    non_root_node_ids = setdiff(graph_node_ids, Set([root_node_id]))

    valid = true

    for v in load.values
        if !(v.node_id in graph_node_ids)
            push!(
                e,
                AssertionError("Load node_id ($(v.node_id)) not found in graph"),
            )
            valid = false
        end
    end

    load_bus_ids = Set([v.bus_id for v in load.values])
    for node_id in non_root_node_ids
        for bus_id in load_bus_ids
            has_entry = any(
                v -> v.bus_id == bus_id && v.node_id == node_id, load.values
            )
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

    return valid
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_scenarios_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_graph = __build_graph!(d, e)
    valid_inflow = __build_inflow_scenarios!(d, e)
    valid_load = __build_load_scenarios!(d, e)
    return valid_graph && valid_inflow && valid_load
end

function __cast_scenarios_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_scenarios_keys_types_before_build!(d, e)
    valid_graph = valid_key_types && __cast_graph_internals_from_files!(d, e)
    valid_inflow = valid_key_types && __cast_inflow_scenarios_internals_from_files!(d, e)
    valid_load = valid_key_types && __cast_load_scenarios_internals_from_files!(d, e)
    return valid_graph && valid_inflow && valid_load
end
