module System

using JSON
using CSV
using DataFrames
using JuMP
using Graphs

import Base: length

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
    length(ses::SystemEntitySet)

Return the number of dimensions (elements) in an entity set
"""
length(ses::SystemEntitySet)

"""
get_params_df(ses)

Return the parameters of the entities in the set as a DataFrame
"""
get_params_df(ses::SystemEntitySet)

include("../reading-utils.jl")
include("../validation-utils.jl")

include("bus-validators.jl")
include("bus.jl")

include("line-validators.jl")
include("line.jl")

include("hydro-validators.jl")
include("hydro.jl")

# include("thermal-validators.jl")
# include("thermal.jl")

include("configuration-validators.jl")
include("configuration.jl")

end
