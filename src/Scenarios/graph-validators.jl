# SCHEMAS ----------------------------------------------------------------------------------

const NODE_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("stage", Integer; constraints = [positive()]),
    FieldRule("start_datetime", DateTime),
    FieldRule("end_datetime", DateTime),
]

const EDGE_SCHEMA = [
    FieldRule("source", Integer),
    FieldRule("target", Integer),
    FieldRule("probability", Real; constraints = [in_range(0.0, 1.0)]),
    FieldRule("discount_rate", Real; constraints = [non_negative()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_graph_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["nodes", "edges"]
    valid_keys = __validate_keys!(d, keys, e)
    if !valid_keys
        return false
    end
    valid_nodes_type = isa(d["nodes"], Vector)
    valid_nodes_type ||
        push!(e, ErrorException("Key 'nodes' ($(d["nodes"])) can't be converted to Vector"))
    valid_edges_type = isa(d["edges"], Vector)
    valid_edges_type ||
        push!(e, ErrorException("Key 'edges' ($(d["edges"])) can't be converted to Vector"))
    return valid_nodes_type && valid_edges_type
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_node_datetimes!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    start_dt = d["start_datetime"]
    end_dt = d["end_datetime"]
    valid = end_dt > start_dt
    valid || push!(
        e,
        AssertionError(
            "Node $id - end_datetime ($end_dt) must be greater than start_datetime ($start_dt)",
        ),
    )
    return valid
end

function __validate_node_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_schema = validate_schema!(
        d, NODE_SCHEMA, e; entity_label = "Node $(get(d, "id", "?"))"
    )
    valid_datetimes = valid_schema && __validate_node_datetimes!(d, e)
    return valid_schema && valid_datetimes
end

function __validate_edge_source_target!(
    d::Dict{String,Any}, nodes::Vector{Node}, e::CompositeException
)::Bool
    source_id = d["source"]
    target_id = d["target"]
    node_ids = [n.id for n in nodes]
    valid_source = source_id in node_ids
    valid_source || push!(
        e,
        AssertionError("Edge - source node id ($source_id) not found in nodes"),
    )
    valid_target = target_id in node_ids
    valid_target || push!(
        e,
        AssertionError("Edge - target node id ($target_id) not found in nodes"),
    )
    return valid_source && valid_target
end

function __validate_edge_content!(
    d::Dict{String,Any}, nodes::Vector{Node}, e::CompositeException
)::Bool
    valid_schema = validate_schema!(d, EDGE_SCHEMA, e)
    valid_source_target = valid_schema && __validate_edge_source_target!(d, nodes, e)
    return valid_schema && valid_source_target
end

function __validate_graph_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    nodes = d["nodes"]
    valid = length(nodes) >= 1
    valid || push!(e, AssertionError("Graph must have at least 1 node"))
    return valid
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_graph_unique_node_ids!(
    nodes::Vector{Node}, e::CompositeException
)::Bool
    node_ids = [n.id for n in nodes]
    valid = length(unique(node_ids)) == length(node_ids)
    valid || push!(e, AssertionError("Graph - node ids must be unique"))
    return valid
end

function __validate_graph_single_root!(
    nodes::Vector{Node}, edges::Vector{Edge}, e::CompositeException
)::Bool
    node_ids = [n.id for n in nodes]
    target_ids = [edge.target[].id for edge in edges]
    unique!(target_ids)
    root_ids = setdiff(node_ids, target_ids)
    valid = length(root_ids) == 1
    valid || push!(
        e,
        AssertionError(
            "Graph must have exactly one root node, found $(length(root_ids)): $root_ids",
        ),
    )
    return valid
end

function __validate_graph_probability_sums!(
    nodes::Vector{Node}, edges::Vector{Edge}, e::CompositeException
)::Bool
    valid = true
    for node in nodes
        outgoing = [edge for edge in edges if edge.source[].id == node.id]
        if !isempty(outgoing)
            prob_sum = sum(edge.probability for edge in outgoing)
            valid_sum = abs(prob_sum - 1.0) <= 1e-6
            valid_sum || push!(
                e,
                AssertionError(
                    "Graph - outgoing probabilities from node $(node.id) sum to $prob_sum, expected 1.0",
                ),
            )
            valid = valid && valid_sum
        end
    end
    return valid
end

function __validate_graph_reachability!(
    nodes::Vector{Node}, edges::Vector{Edge}, e::CompositeException
)::Bool
    node_ids = [n.id for n in nodes]
    target_ids = [edge.target[].id for edge in edges]
    unique!(target_ids)
    root_ids = setdiff(node_ids, target_ids)

    length(root_ids) == 1 || return true

    root_id = root_ids[1]
    reachable = Set{Integer}([root_id])
    frontier = [root_id]
    while !isempty(frontier)
        current = popfirst!(frontier)
        for edge in edges
            if edge.source[].id == current
                tid = edge.target[].id
                if !(tid in reachable)
                    push!(reachable, tid)
                    push!(frontier, tid)
                end
            end
        end
    end

    unreachable = setdiff(Set(node_ids), reachable)
    valid = isempty(unreachable)
    valid || push!(
        e,
        AssertionError(
            "Graph - nodes $unreachable are not reachable from root node $root_id",
        ),
    )
    return valid
end

function __validate_graph_consistency!(
    nodes::Vector{Node}, edges::Vector{Edge}, e::CompositeException
)::Bool
    valid_unique_ids = __validate_graph_unique_node_ids!(nodes, e)
    valid_single_root = __validate_graph_single_root!(nodes, edges, e)
    valid_probability_sums = __validate_graph_probability_sums!(nodes, edges, e)
    valid_reachability = __validate_graph_reachability!(nodes, edges, e)
    return valid_unique_ids && valid_single_root && valid_probability_sums &&
           valid_reachability
end

