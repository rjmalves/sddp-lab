module Inputs

using ..Core
using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Tasks

# TYPES ------------------------------------------------------------------------

struct InputsData
    path::String
    files::Vector{InputModule}
end

# TODO - for typing optimizer (as MOI.AbstractOptimizer),
# need to add MOI to dependencies. Is it worth?
struct Entrypoint
    inputs::InputsData
    optimizer
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
get_path(e::Entrypoint)::String

Return the path where the input files were located.
"""
function get_path(e::Entrypoint)::String
    return e.inputs.path
end

"""
get_files(e::Entrypoint)::Vector{InputModule}

Return the file objects from the entrypoint.
"""
function get_files(e::Entrypoint)::Vector{InputModule}
    return e.inputs.files
end

# INTERNALS ------------------------------------------------------------------------

include("inputsdata-validators.jl")
include("inputsdata.jl")

include("entrypoint-validators.jl")
include("entrypoint.jl")

export Entrypoint, get_files, get_path
end