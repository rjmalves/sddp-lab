
function Graph(d::Dict{String,Any}, e::CompositeException)

    # __validate_nodes
    # __validate_edges

    nodes = [__build_node(node) for node in d["nodes"]]
    edges = [__build_edge(edge, nodes) for edge in d["edges"]]

    root_index = findfirst(n -> n.id == 0, nodes)
    if root_index === nothing
        # no explicit root in the dict: synthesize one and wire it to the entry node(s)
        root_node = __build_synthetic_root(nodes)
        entry_nodes = __find_entry_nodes(nodes, edges)
        root_edges = [Edge(Ref(root_node), Ref(n), 1.0, 0.0) for n in entry_nodes]
        edges = vcat(root_edges, edges)
    else
        # id=0 node provided: use it as root, keep only decision nodes in `nodes`
        root_node = nodes[root_index]
        nodes = filter(n -> n.id != 0, nodes)
    end

    return Graph(nodes, edges, root_node)
end

function Graph(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    return valid_jsonc ? Graph(d, e) : nothing
end

function __build_node(d::Dict{String,Any})::Node
    id = Int(d["id"]) # this Int() call should be moved to __validate above
    stage = Int(d["stage"]) # this Int() call should be moved to __validate above
    start_datetime = DateTime(d["start_datetime"]) # this DateTime() call should be moved to __validate above
    end_datetime = DateTime(d["end_datetime"]) # should also be in a validate

    return Node(id, stage, start_datetime, end_datetime)
end

function __build_edge(d::Dict{String,Any}, nodes::Vector{Node})::Edge
    source_id = Int(d["source"]) # should be validated
    target_id = Int(d["target"]) # should be validated
    source_node = nodes[findfirst(==(source_id), [node.id for node in nodes])]
    target_node = nodes[findfirst(==(target_id), [node.id for node in nodes])]
    probability = Real(d["probability"]) # should be validated
    discount_rate = Real(d["discount_rate"]) # should be validated

    return Edge(Ref(source_node), Ref(target_node), probability, discount_rate)
end

# GENERAL METHODS -----------------------------------------------------------------------

# HELPERS -------------------------------------------------------------------------------------

function __find_entry_nodes(nodes::Vector{Node}, edges::Vector{Edge})::Vector{Node}
    targets = Set(e.target[].id for e in edges)
    return [n for n in nodes if !(n.id in targets)]
end

function __build_synthetic_root(nodes::Vector{Node})::Node
    earliest = minimum(n -> n.start_datetime, nodes)
    return Node(0, 0, earliest, earliest)   # id=0, stage=0, zero-width interval at t0
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