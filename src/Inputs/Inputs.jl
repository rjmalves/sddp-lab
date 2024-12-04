module Inputs

using ..Core
using ..Algorithm
using ..System
using ..Utils
using ..Scenarios
using ..Tasks
using JuMP

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

"""
get_optimizer(e::Entrypoint)

Return the optimizer object given to the optimization process.
"""
function get_optimizer(e::Entrypoint)
    return e.optimizer
end

# INTERNALS ------------------------------------------------------------------------

include("inputsdata-validators.jl")
include("inputsdata.jl")

include("entrypoint-validators.jl")
include("entrypoint.jl")

export Entrypoint, get_files, get_path, get_optimizer
end