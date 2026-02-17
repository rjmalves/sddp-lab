# CLASS Node -----------------------------------------------------------------------

function Node(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_node_content!(d, e)

    return if valid
        Node(d["id"], d["stage"], d["start_datetime"], d["end_datetime"])
    else
        nothing
    end
end

# CLASS Edge -----------------------------------------------------------------------

function Edge(d::Dict{String,Any}, nodes::Vector{Node}, e::CompositeException)
    valid = __validate_edge_content!(d, nodes, e)

    return if valid
        source_id = d["source"]
        target_id = d["target"]
        source_node = nodes[findfirst(==(source_id), [node.id for node in nodes])]
        target_node = nodes[findfirst(==(target_id), [node.id for node in nodes])]
        Edge(Ref(source_node), Ref(target_node), d["probability"], d["discount_rate"])
    else
        nothing
    end
end

# CLASS Graph -----------------------------------------------------------------------

function Graph(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_graph_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_graph_keys_types_after_build!(d, e)
    valid_content = valid_keys_types && __validate_graph_content!(d, e)
    valid_consistency =
        valid_content && __validate_graph_consistency!(d["nodes"], d["edges"], e)

    return if valid_consistency
        Graph(d["nodes"], d["edges"])
    else
        nothing
    end
end

function Graph(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    return valid_jsonc ? Graph(d, e) : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __validate_graph_keys_types_after_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["nodes", "edges"], e)
    if !valid_keys
        return false
    end
    valid_nodes = isa(d["nodes"], Vector{Node})
    valid_nodes ||
        push!(e, ErrorException("Key 'nodes' ($(d["nodes"])) can't be converted to Vector{Node}"))
    valid_edges = isa(d["edges"], Vector{Edge})
    valid_edges ||
        push!(e, ErrorException("Key 'edges' ($(d["edges"])) can't be converted to Vector{Edge}"))
    return valid_nodes && valid_edges
end

function __build_graph_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_graph_keys = __validate_graph_keys_types!(d, e)
    if !valid_graph_keys
        return false
    end

    nodes = Node[]
    valid_nodes = true
    for node_d in d["nodes"]
        node = Node(node_d, e)
        if node !== nothing
            push!(nodes, node)
        end
        valid_nodes = valid_nodes && node !== nothing
    end
    d["nodes"] = nodes

    if !valid_nodes
        return false
    end

    edges = Edge[]
    valid_edges = true
    for edge_d in d["edges"]
        edge = Edge(edge_d, nodes, e)
        if edge !== nothing
            push!(edges, edge)
        end
        valid_edges = valid_edges && edge !== nothing
    end
    d["edges"] = edges

    return valid_nodes && valid_edges
end

function __build_graph!(d::Dict{String,Any}, e::CompositeException)::Bool
    d["graph"] = Graph(d["graph"]["params"], e)
    return d["graph"] !== nothing
end

function __cast_graph_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    graph_d = d["graph"]
    should_cast_from_file = __validate_file_key!(graph_d, e)

    valid = !should_cast_from_file
    if should_cast_from_file
        valid = __validate_cast_from_jsonc_file!(graph_d, e)
    end

    return valid
end
