# CLASS Environment -----------------------------------------------------------------------

struct Environment
    solver::Solver
    # strategy::Strategy
    # processes::Processes
    # communication::Communication
    # manager::Manager
end

function Environment(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_environment_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_environment_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_environment_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_environment_consistency!(d, e)

    return if valid_consistency
        Environment(d["solver"])
    else
        nothing
    end
end

function Environment(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_environment_internals_from_files!(d, e)

    return valid ? Environment(d, e) : nothing
end