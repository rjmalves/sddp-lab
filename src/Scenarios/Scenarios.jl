module Scenarios

using JuMP

using Random
using ..Core
using ..Utils
using ..StochasticProcess

import Base: length

# TODO - change to be an abstract scenario entity when
# the load is also an stochastic process

struct InflowScenarios
    stochastic_process::AbstractStochasticProcess
end

abstract type LoadScenarios end

"""
    __get_ids(s)

Return the `id`s of elements represented in a load scenarios object
"""
function __get_ids(s::LoadScenarios) end

"""
    length(s::LoadScenarios)

Return the number of dimensions (elements) in the load scenarios
"""
function length(s::LoadScenarios) end

struct ScenariosData <: InputModule
    seed::Integer
    initial_season::Integer
    branchings::Integer
    inflow::InflowScenarios
    load::LoadScenarios
end

# TODO - this will change once we have a proper load representation
"""
    __get_load(m, s)

Gets the load value for a given bus and stage
"""
function __get_load(bus_id::Integer, stage_index::Integer, load::LoadScenarios)::Real end

# TODO - this will change once we have a proper load representation
"""
    get_load(m, s)

Gets the load value for a given bus and stage
"""
function get_load(bus_id::Integer, stage_index::Integer, scenarios::ScenariosData)::Real
    return __get_load(bus_id, stage_index, scenarios.load)
end

"""
    set_seed!(scenarios::ScenariosData)

Sets the seed to be used in RNG
"""
function set_seed!(scenarios::ScenariosData)
    return Random.seed!(scenarios.seed)
end

"""
    generate_saa(scenarios::ScenariosData, num_stages::Integer)

Generates the SAA scenarios for the inflow, for parametrizing in the SDDP algorithm.
"""
function generate_saa(scenarios::ScenariosData, num_stages::Integer)
    inflow = scenarios.inflow.stochastic_process
    initial_season = scenarios.initial_season
    branchings = scenarios.branchings
    return StochasticProcess.generate_saa(inflow, initial_season, num_stages, branchings)
end

"""
    add_uncertainties!(m::JuMP.Model, scenarios::ScenariosData)

Generates the SAA scenarios for the inflow, for parametrizing in the SDDP algorithm.
"""
function add_uncertainties!(m::JuMP.Model, scenarios::ScenariosData, node::Int)
    inflow = scenarios.inflow.stochastic_process
    
    # TODO - for when we have a proper load representation
    # add_load_uncertainty!(m, load)

    season = __node2season(node, size(inflow, 2), scenarios.initial_season)
    return add_inflow_uncertainty!(m, inflow, season)
end

include("inflow-validators.jl")
include("inflow.jl")

include("load-validators.jl")
include("load.jl")

include("scenariosdata-validators.jl")
include("scenariosdata.jl")

export ScenariosData, add_uncertainties!, generate_saa, get_load, get_scenarios, set_seed!

end