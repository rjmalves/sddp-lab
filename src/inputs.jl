using .Algorithm
using .Resources
using .System
using .Utils

# INPUTS --------------------------------------------------------------------------------------

struct InputFiles
    strategy::Strategy
    environment::Environment
    configuration::Configuration
end

struct Inputs
    path::String
    files::InputFiles
end

function read_validate_entrypoint!(
    filename::String, e::CompositeException
)::Union{Dict{String,Any},Nothing}
    d = read_jsonc(filename, e)

    valid = __validate_entrypoint!(d, e)
    if !valid
        return nothing
    end

    entrypoint_directory = dirname(filename)
    if entrypoint_directory != ""
        cd(entrypoint_directory)
    end

    return valid ? d : nothing
end

function __read_validate_input_files!(
    d::Dict{String,Any}, e::CompositeException
)::Union{InputFiles,Nothing}
    valid = __validate_input_files_keys_types!(d, e)
    if !valid
        return nothing
    end

    strategy = Strategy(d["algorithm"], e)
    environment = Environment(d["resources"], e)
    configuration = Configuration(d["system"], e)

    valid_files =
        strategy !== nothing && environment !== nothing && configuration !== nothing

    return valid_files ? InputFiles(strategy, environment, configuration) : nothing
end

function read_validate_inputs!(
    d::Dict{String,Any}, e::CompositeException
)::Union{Inputs,Nothing}
    curdir = pwd()

    valid = __validate_inputs!(d, e)
    if !valid
        cd(curdir)
        return nothing
    end

    files = __read_validate_input_files!(d["files"], e)
    valid_files = files !== nothing

    cd(curdir)

    return valid_files ? Inputs(d["path"], files) : nothing
end
