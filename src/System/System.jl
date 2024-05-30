module System

using DataFrames

abstract type SystemEntity end

"""
get_id(s)

Return the `id` of the system entity
"""
get_id(se::SystemEntity)

"""
get_params(s)

Return parameters that are specific to the system entity, as a dictionary
"""
get_params(se::SystemEntity)

"""
add_system_element!(m, s)

Add state variables, decision variables and constraints to a JuMP model `m`
"""
add_system_element!(m::JuMP.Model, se::SystemEntity)

abstract type SystemEntitySet end

"""
get_ids(ses)

Return the `id` of each entity in the set
"""
get_ids(ses::SystemEntitySet)

"""
get_params_df(ses)

Return the parameters of the entities in the set as a DataFrame
"""
get_params_df(ses::SystemEntitySet)

include("../validation-utils.jl")

include("bus-validators.jl")
include("bus.jl")

include("hydro-validators.jl")
include("hydro.jl")

end