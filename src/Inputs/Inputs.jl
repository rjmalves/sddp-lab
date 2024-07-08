module Inputs

using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Tasks

struct Files
    algorithm::AlgorithmData
    resources::ResourcesData
    system::SystemData
    scenarios::ScenariosData
    tasks::TasksData
end

struct InputsData
    path::String
    files::Files
end

struct Entrypoint
    inputs::InputsData
end

"""
get_files(e::Entrypoint)::Files

Return the file objects from the entrypoint.
"""
function get_files(e::Entrypoint)::Files
    return e.inputs.files
end

"""
get_tasks(f::Files)::Vector{TaskDefinition}

Return the task definitions from the read files.
"""
function get_tasks(f::Files)::Vector{TaskDefinition}
    return f.tasks.tasks
end
"""
get_system(f::Files)::SystemData

Return the system object from files.
"""
function get_system(f::Files)::SystemData
    return f.system
end

"""
get_hydros(f::Files)::Hydros

Return the hydro object from files.
"""
function get_hydros(f::Files)::Hydros
    return f.system.hydros
end

"""
get_hydros_entities(f::Files)::Vector{Hydro}

Return the hydro entities from files.
"""
function get_hydros_entities(f::Files)::Vector{Hydro}
    return f.system.hydros.entities
end

"""
get_buses(f::Files)::Buses

Return the buses object from files.
"""
function get_buses(f::Files)::Buses
    return f.system.buses
end

"""
get_buses_entities(f::Files)::Vector{Bus}

Return the bus entities from files.
"""
function get_buses_entities(f::Files)::Vector{Bus}
    return f.system.buses.entities
end

"""
get_thermals_entities(f::Files)::Vector{Thermal}

Return the thermal entities from files.
"""
function get_thermals_entities(f::Files)::Vector{Thermal}
    return f.system.thermals.entities
end
"""
get_algorithm(f::Files)::AlgorithmData

Return the algorithm object from files.
"""
function get_algorithm(f::Files)::AlgorithmData
    return f.algorithm
end
"""
get_horizon(f::Files)::Horizon

Return the horizon object from files.
"""
function get_horizon(f::Files)::Horizon
    return f.algorithm.horizon
end
"""
get_number_of_stages(f::Files)::Integer

Return the number of stages from files.
"""
function get_number_of_stages(f::Files)::Integer
    return length(get_horizon(f))
end
"""
get_scenario_graph(f::Files)::ScenarioGraph

Return the scenario graph object from files.
"""
function get_scenario_graph(f::Files)::ScenarioGraph
    return f.algorithm.graph
end
"""
get_scenarios(f::Files)::ScenariosData

Return the scenario object from files.
"""
function get_scenarios(f::Files)::ScenariosData
    return f.scenarios
end

include("files-validators.jl")
include("files.jl")

include("inputsdata-validators.jl")
include("inputsdata.jl")

include("entrypoint-validators.jl")
include("entrypoint.jl")

export Entrypoint,
    Files,
    get_files,
    get_tasks,
    get_system,
    get_hydros,
    get_hydros_entities,
    get_buses,
    get_buses_entities,
    get_thermals_entities,
    get_algorithm,
    get_number_of_stages,
    get_horizon,
    get_scenario_graph,
    get_scenarios
end