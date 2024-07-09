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

struct Entrypoint
    inputs::InputsData
end

# GENERAL METHODS ------------------------------------------------------------------------

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

export Entrypoint, get_files
end