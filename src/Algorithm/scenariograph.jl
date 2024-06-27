# CLASS RegularScenarioGraph -----------------------------------------------------------------------

struct RegularScenarioGraph <: ScenarioGraph
    discount_rate::Real
end

function RegularScenarioGraph(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_regular_scenario_graph_keys_types!(d, e)
    valid_content =
        valid_keys_types ? __validate_regular_scenario_graph_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? RegularScenarioGraph(d["discount_rate"]) : nothing
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

# HELPERS -------------------------------------------------------------------------------------

function __build_scenario_graph!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_scenario_graph_key = __validate_keys!(d, ["scenario_graph"], e)
    valid_scenario_graph_type =
        valid_scenario_graph_key &&
        __validate_key_types!(d, ["scenario_graph"], [Dict{String,Any}], e)
    if !valid_scenario_graph_type
        return false
    end

    scenario_graph_d = d["scenario_graph"]
    keys = ["kind", "params"]
    keys_types = [String, Dict{String,Any}]
    valid_keys = __validate_keys!(scenario_graph_d, keys, e)
    valid_types = valid_keys && __validate_key_types!(scenario_graph_d, keys, keys_types, e)
    if !valid_types
        return false
    end

    kind = scenario_graph_d["kind"]
    params = scenario_graph_d["params"]

    scenario_graph_obj = nothing

    try
        kind_type = getfield(@__MODULE__, Symbol(kind))
        scenario_graph_obj = kind_type(params, e)
    catch
        push!(e, AssertionError("Scenario graph kind ($kind) not recognized"))
    end
    d["scenario_graph"] = scenario_graph_obj

    return scenario_graph_obj !== nothing
end