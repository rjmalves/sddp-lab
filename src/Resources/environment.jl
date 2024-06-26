# CLASS Environment -----------------------------------------------------------------------

struct Environment
    solver::Solver
    # strategy::Strategy
    # processes::Processes
    # communication::Communication
    # manager::Manager
end

function Environment(d::Dict{String,Any}, e::CompositeException)

    # Keys and types validation pre build
    valid_keys_types_pre_build = __validate_environment_keys_types_pre_build!(d, e)
    if !valid_keys_types_pre_build
        return nothing
    end

    # Build internal objects
    valid_solver = __build_solver!(d, e)
    valid_internals = valid_solver

    # Keys and types validation pos build
    valid_keys_types = valid_internals && __validate_environment_keys_types_pos_build!(d, e)

    # Content validation
    valid = valid_keys_types && valid_internals

    return if valid
        Environment(d["solver"])
    else
        nothing
    end
end

function Environment(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    valid = valid_jsonc
    return valid ? Environment(d, e) : nothing
end