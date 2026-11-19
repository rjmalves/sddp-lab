module Inputs

using ..Lab
using ..System
using ..Utils
using ..Scenarios

# TYPES ------------------------------------------------------------------------

struct InputsData
    path::String
    files::Vector{InputModule}
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
get_path(i::InputsData)::String

Return the path where the input files were located.
"""
function get_path(i::InputsData)::String
    return i.path
end

"""
get_files(i::InputsData)::Vector{InputModule}

Return the file objects from the input data.
"""
function get_files(i::InputsData)::Vector{InputModule}
    return i.files
end

# INTERNALS ------------------------------------------------------------------------

include("inputsdata-validators.jl")
include("inputsdata.jl")

export InputsData, get_files, get_path
end
