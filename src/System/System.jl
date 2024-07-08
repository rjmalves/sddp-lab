module System

using JSON
using CSV
using DataFrames
using JuMP
using Graphs
using SDDP: SDDP

using ..Core
using ..Utils

import Base: length

abstract type SystemEntity end

struct Bus <: SystemEntity
    id::Integer
    name::String
    deficit_cost::Real
end

struct Line <: SystemEntity
    id::Integer
    name::String
    source_bus_id::Integer
    target_bus_id::Integer
    capacity::Real
    exchange_penalty::Real
    # References to other system elements
    source_bus::Ref{Bus}
    target_bus::Ref{Bus}
end

struct Hydro <: SystemEntity
    id::Integer
    downstream_id::Integer
    name::String
    bus_id::Integer
    productivity::Real
    initial_storage::Real
    min_storage::Real
    max_storage::Real
    min_generation::Real
    max_generation::Real
    spillage_penalty::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

struct Thermal <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    min_generation::Real
    max_generation::Real
    cost::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

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

struct Buses <: SystemEntitySet
    entities::Vector{Bus}
end

struct Lines <: SystemEntitySet
    entities::Vector{Line}
end

struct Hydros <: SystemEntitySet
    entities::Vector{Hydro}
    topology::DiGraph
end

struct Thermals <: SystemEntitySet
    entities::Vector{Thermal}
end

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

function __cast_system_entity_from_file!(d::Dict{String,Any}, e::CompositeException)::Bool
    df = read_csv(d["file"], e)
    valid_df = df !== nothing
    internal_d = valid_df ? __dataframe_to_dict(df) : nothing
    valid_file_data = internal_d !== nothing
    if valid_file_data
        d["entities"] = internal_d
    end
    return valid_file_data
end

function __validate_system_entity_file_key!(d::Dict{String,Any}, e::CompositeException)
    has_file_key = haskey(d, "file")
    valid_file_key = has_file_key && __validate_key_types!(d, ["file"], [String], e)
    return valid_file_key
end

function __fill_default_values!(
    entities::Vector{Dict{String,Any}}, default_values::Dict{String,Any}
)
    for e in entities
        for (k, v) in e
            if v === missing
                e[k] = default_values[k]
            end
        end
    end
end

function __fill_system_entity_default_values!(d::Dict{String,Any}, e::CompositeException)
    entities = d["entities"]
    default_values = haskey(d, "default_values") ? d["default_values"] : Dict{String,Any}()
    valid = __validate_required_default_values!(d["entities"], default_values, e)
    !valid || __fill_default_values!(entities, default_values)
    return nothing
end

function __cast_system_entities_content!(
    d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    entities_d = d[key]
    should_cast_from_file = __validate_system_entity_file_key!(entities_d, e)

    valid = !should_cast_from_file
    if should_cast_from_file
        valid = __cast_system_entity_from_file!(entities_d, e)
    end

    if valid
        __fill_system_entity_default_values!(entities_d, e)
    end

    return valid
end

include("bus-validators.jl")
include("bus.jl")

include("line-validators.jl")
include("line.jl")

include("hydro-validators.jl")
include("hydro.jl")

include("thermal-validators.jl")
include("thermal.jl")

include("systemdata-validators.jl")
include("systemdata.jl")

export SystemData,
    Hydro,
    Hydros,
    Bus,
    Buses,
    Thermal,
    Thermals,
    add_system_elements!,
    add_system_objective!,
    get_ids

end
