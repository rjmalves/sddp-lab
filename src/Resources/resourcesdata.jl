# CLASS ResourcesData -----------------------------------------------------------------------

struct ResourcesData <: InputModule
    solver::Solver
    # strategy::Strategy
    # processes::Processes
    # communication::Communication
    # manager::Manager
end

function ResourcesData(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_resources_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_resources_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_resources_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_resources_consistency!(d, e)

    return if valid_consistency
        ResourcesData(d["solver"])
    else
        nothing
    end
end

function ResourcesData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_resources_internals_from_files!(d, e)

    return valid ? ResourcesData(d, e) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

"""
get_resources(s::Vector{InputModule})::ResourcesData

Return the ResourcesData object from files.
"""
function get_resources(f::Vector{InputModule})::ResourcesData
    return get_input_module(f, ResourcesData)
end

"""
get_solver(s::ResourcesData)::Solver

Return the Solver object from files.
"""
function get_solver(s::ResourcesData)::Solver
    return s.solver
end

# SDDP METHODS --------------------------------------------------------------------------

"""
generate_optimizer(s::ResourcesData)

Generates the SDDP.jl graph for building the model.
"""
function generate_optimizer(s::ResourcesData)
    return generate_optimizer(get_solver(s))
end