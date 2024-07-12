# CLASS RegularScenarioGraph -----------------------------------------------------------------------

function RegularScenarioGraph(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_regular_scenario_graph_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types =
        valid_internals && __validate_regular_scenario_graph_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_regular_scenario_graph_content!(d, e)

    # Consistency validation
    valid_consistency =
        valid_content && __validate_regular_scenario_graph_consistency!(d, e)

    return valid_consistency ? RegularScenarioGraph(d["discount_rate"]) : nothing
end

# TODO

# CLASS CyclicScenarioGraph -----------------------------------------------------------------------

function CyclicScenarioGraph(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_cyclic_scenario_graph_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_cyclic_scenario_graph_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_cyclic_scenario_graph_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_cyclic_scenario_graph_consistency!(d, e)

    return if valid_consistency
        CyclicScenarioGraph(
            d["discount_rate"], d["cycle_length"], d["cycle_stage"], d["max_depth"]
        )
    else
        nothing
    end
end

# GENERAL METHODS -----------------------------------------------------------------------

function get_scenario_graph_max_depth(g::RegularScenarioGraph)::Integer
    return 0
end

function get_scenario_graph_max_depth(g::CyclicScenarioGraph)::Integer
    return g.max_depth
end

# SDDP METHODS -----------------------------------------------------------------------

function generate_scenario_graph(g::RegularScenarioGraph, num_stages::Integer)::SDDP.Graph
    graph = SDDP.Graph(0)
    edge_prob = g.discount_rate

    for s in 1:num_stages
        SDDP.add_node(graph, s)
        SDDP.add_edge(graph, s - 1 => s, edge_prob)
    end

    return graph
end

function generate_scenario_graph(g::CyclicScenarioGraph, num_stages::Integer)::SDDP.Graph
    graph = SDDP.Graph(0)
    edge_prob = g.discount_rate

    for s in 1:(g.cycle_stage - 1)
        SDDP.add_node(graph, s)
        SDDP.add_edge(graph, s - 1 => s, edge_prob)
    end
    for s in (g.cycle_stage):(g.cycle_stage + g.cycle_length - 1)
        SDDP.add_node(graph, s)
        SDDP.add_edge(graph, s - 1 => s, edge_prob)
    end
    SDDP.add_edge(graph, (g.cycle_length + g.cycle_stage - 1) => g.cycle_stage, edge_prob)

    return graph
end

# HELPERS -------------------------------------------------------------------------------------

function __build_scenario_graph!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_scenario_graph_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "scenario_graph", e)
end

function __cast_scenario_graph_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
