module Scenarios

using JuMP

using Random
using Dates
using ..Lab
using ..Utils
using ..StochasticProcess

import Base: length

# TODO - change to be an abstract scenario entity when
# the load is also an stochastic process

struct InflowScenarios
    stochastic_process::AbstractStochasticProcess
end

abstract type LoadScenarios end

struct Node
    id::Integer
    stage::Integer
    start_datetime::DateTime
    end_datetime::DateTime
end

struct Edge
    source::Ref{Node}
    target::Ref{Node}
    probability::Real
    discount_rate::Real
end

struct Graph
    nodes::Vector{Node}
    edges::Vector{Edge}
end

function __get_ids(s::LoadScenarios) end
function length(s::LoadScenarios) end

struct ScenariosData <: InputModule
    seed::Integer
    initial_season::Integer
    branchings::Integer
    graph::Graph
    inflow::InflowScenarios
    load::LoadScenarios
end

function __get_load(bus_id::Integer, node_id::Integer, load::LoadScenarios)::Real end

function get_load(bus_id::Integer, node_id::Integer, scenarios::ScenariosData)::Real
    return __get_load(bus_id, node_id, scenarios.load)
end

function set_seed!(scenarios::ScenariosData)
    return Random.seed!(scenarios.seed)
end

function get_graph(scenarios::ScenariosData)
    return scenarios.graph
end

function get_number_of_stages(g::Graph)::Integer
    node_stages = [n.stage for n in g.nodes]
    unique!(node_stages)
    return length(node_stages)
end

function get_root_node_id(g::Graph)::Integer
    node_ids = [n.id for n in g.nodes]
    nodes_with_targets = [e.target[].id for e in g.edges]
    unique!(node_ids)
    unique!(nodes_with_targets)
    node_ids = setdiff(node_ids, nodes_with_targets)
    return node_ids[1]
end

include("graph-validators.jl")
include("graph.jl")

include("inflow-validators.jl")
include("inflow.jl")

include("load-validators.jl")
include("load.jl")

include("scenariosdata-validators.jl")
include("scenariosdata.jl")

export ScenariosData,
    add_uncertainties!,
    generate_saa,
    get_load,
    get_scenarios,
    get_graph,
    get_number_of_stages,
    get_root_node_id,
    set_seed!

end