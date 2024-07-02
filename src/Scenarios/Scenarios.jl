module Scenarios

using JuMP

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

struct Uncertainties
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
function get_load(bus_id::Integer, stage_index::Integer, u::Uncertainties)::Real
    return __get_load(bus_id, stage_index, u.load)
end

"""
    generate_saa(u::Uncertainties, num_stages::Integer)

Generates the SAA scenarios for the inflow, for parametrizing in the SDDP algorithm.
"""
function generate_saa(u::Uncertainties, num_stages::Integer)
    inflow = u.inflow.stochastic_process
    initial_season = u.initial_season
    branchings = u.branchings
    return StochasticProcess.generate_saa(inflow, initial_season, num_stages, branchings)
end

"""
    add_uncertainties!(m::JuMP.Model, u::Uncertainties)

Generates the SAA scenarios for the inflow, for parametrizing in the SDDP algorithm.
"""
function add_uncertainties!(m::JuMP.Model, u::Uncertainties)
    inflow = u.inflow.stochastic_process
    # TODO - for when we have a proper load representation
    # add_load_uncertainty!(m, load)
    return add_inflow_uncertainty!(m, inflow)
end

include("inflow-validators.jl")
include("inflow.jl")

include("load-validators.jl")
include("load.jl")

include("uncertainties-validators.jl")
include("uncertainties.jl")

export Uncertainties, add_uncertainties!, generate_saa, get_load

end