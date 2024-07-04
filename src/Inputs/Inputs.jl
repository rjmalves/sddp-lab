module Inputs

using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Tasks

struct Files
    strategy::Strategy
    environment::Environment
    configuration::Configuration
    uncertainties::Uncertainties
    work::Work
end

struct Reading
    path::String
    files::Files
end

struct Entrypoint
    inputs::Reading
end

"""
get_files(e::Entrypoint)::Files

Return the file objects from the entrypoint.
"""
function get_files(e::Entrypoint)::Files
    return e.inputs.files
end

"""
get_tasks(f::Files)::Vector{TaskDefinition}

Return the task definitions from the read files.
"""
function get_tasks(f::Files)::Vector{TaskDefinition}
    return f.work.tasks
end

include("files-validators.jl")
include("files.jl")

include("reading-validators.jl")
include("reading.jl")

include("entrypoint-validators.jl")
include("entrypoint.jl")

export Entrypoint, Files, get_files, get_tasks

end