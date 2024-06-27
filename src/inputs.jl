using .Algorithm
using .Resources
using .System
using .Utils

# INPUTS --------------------------------------------------------------------------------------

struct Inputs
    strategy::Strategy
    environment::Environment
    configuration::Configuration
end

function __read_validate_entrypoint!(
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

function __read_validate_inputs!(
    d::Dict{String,Any}, e::CompositeException
)::Union{Inputs,Nothing}
    valid = __validate_inputs!(d, e)
    if !valid
        return nothing
    end

    strategy = Strategy(d["files"]["algorithm"], e)
    environment = Environment(d["files"]["resources"], e)
    configuration = Configuration(d["files"]["system"], e)

    valid_inputs =
        strategy !== nothing && environment !== nothing && configuration !== nothing

    return valid_inputs ? Inputs(strategy, environment, configuration) : nothing
end
