module Inputs

using ..Core
using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Tasks

struct InputsData
    path::String
    files::Vector{InputModule}
end

struct Entrypoint
    inputs::InputsData
end

function __get_input_module(i::Vector{InputModule}, kind::Type)::InputModule
    index = findfirst(x -> isa(x, kind), i)
    return i[index]
end

"""
get_files(e::Entrypoint)::Vector{InputModule}

Return the file objects from the entrypoint.
"""
function get_files(e::Entrypoint)::Vector{InputModule}
    return e.inputs.files
end

"""
get_tasks(f::Vector{InputModule})::Vector{TaskDefinition}

Return the task definitions from the read files.
"""
function get_tasks(f::Vector{InputModule})::Vector{TaskDefinition}
    m = __get_input_module(f, TasksData)
    return m.tasks
end

"""
get_system(f::Vector{InputModule})::SystemData

Return the system object from files.
"""
function get_system(f::Vector{InputModule})::SystemData
    return __get_input_module(f, SystemData)
end

"""
get_hydros(f::Vector{InputModule})::Hydros

Return the hydro object from files.
"""
function get_hydros(f::Vector{InputModule})::Hydros
    m = get_system(f)
    return m.hydros
end

"""
get_hydros_entities(f::Vector{InputModule})::Vector{Hydro}

Return the hydro entities from files.
"""
function get_hydros_entities(f::Vector{InputModule})::Vector{Hydro}
    m = get_hydros(f)
    return m.entities
end

"""
get_buses(f::Vector{InputModule})::Buses

Return the buses object from files.
"""
function get_buses(f::Vector{InputModule})::Buses
    m = get_system(f)
    return m.buses
end

"""
get_buses_entities(f::Vector{InputModule})::Vector{Bus}

Return the bus entities from files.
"""
function get_buses_entities(f::Vector{InputModule})::Vector{Bus}
    m = get_buses(f)
    return m.entities
end

"""
get_thermals(f::Vector{InputModule})::Thermals

Return the thermals object from files.
"""
function get_thermals(f::Vector{InputModule})::Thermals
    m = get_system(f)
    return m.thermals
end

"""
get_thermals_entities(f::Vector{InputModule})::Vector{Thermal}

Return the thermal entities from files.
"""
function get_thermals_entities(f::Vector{InputModule})::Vector{Thermal}
    m = get_thermals(f)
    return m.entities
end

"""
get_algorithm(f::Vector{InputModule})::AlgorithmData

Return the algorithm object from files.
"""
function get_algorithm(f::Vector{InputModule})::AlgorithmData
    return __get_input_module(f, AlgorithmData)
end

"""
get_horizon(f::Vector{InputModule})::Horizon

Return the horizon object from files.
"""
function get_horizon(f::Vector{InputModule})::Horizon
    m = get_algorithm(f)
    return m.horizon
end
"""
get_number_of_stages(f::Vector{InputModule})::Integer

Return the number of stages from files.
"""
function get_number_of_stages(f::Vector{InputModule})::Integer
    return length(get_horizon(f))
end
"""
get_scenario_graph(f::Vector{InputModule})::ScenarioGraph

Return the scenario graph object from files.
"""
function get_scenario_graph(f::Vector{InputModule})::ScenarioGraph
    m = get_algorithm(f)
    return m.graph
end
"""
get_scenarios(f::Vector{InputModule})::ScenariosData

Return the scenario object from files.
"""
function get_scenarios(f::Vector{InputModule})::ScenariosData
    return __get_input_module(f, ScenariosData)
end

include("inputsdata-validators.jl")
include("inputsdata.jl")

include("entrypoint-validators.jl")
include("entrypoint.jl")

export Entrypoint,
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