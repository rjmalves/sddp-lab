module System

using JSON
using CSV
using DataFrames
using JuMP
using Graphs
using SDDP

using ..Utils

import Base: length

abstract type SystemEntity end

"""
get_id(s)

Return the `id` of the system entity
"""
function get_id(se::SystemEntity)::Integer end

"""
get_params(s)

Return parameters that are specific to the system entity, as a dictionary
"""
function get_params(se::SystemEntity)::Dict{String,Any} end

abstract type SystemEntitySet end

"""
get_ids(ses)

Return the `id` of each entity in the set
"""
function get_ids(ses::SystemEntitySet)::Vector{Integer} end

"""
    length(ses::SystemEntitySet)

Return the number of dimensions (elements) in an entity set
"""
function length(ses::SystemEntitySet)::Integer end

"""
get_params_df(ses)

Return the parameters of the entities in the set as a DataFrame
"""
function get_params_df(ses::SystemEntitySet)::DataFrame end

"""
add_system_elements!(m, ses)

Add state variables, decision variables and constraints to a JuMP model `m`
"""
function add_system_elements!(m::JuMP.Model, ses::SystemEntitySet) end

include("bus-validators.jl")
include("bus.jl")

include("line-validators.jl")
include("line.jl")

include("hydro-validators.jl")
include("hydro.jl")

include("thermal-validators.jl")
include("thermal.jl")

include("configuration-validators.jl")
include("configuration.jl")

export Configuration, add_system_elements!, downstream

end
