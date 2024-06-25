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
    valid_solver = __build_solver!(d, e)
    valid_internals = valid_solver

    # Keys and types validation
    valid_keys_types = valid_internals ? __validate_environment_keys_types!(d, e) : false

    # Content validation
    valid = valid_keys_types && valid_internals

    return if valid
        Environment(d["solver"])
    else
        nothing
    end
end

function Environment(filename::String, e::CompositeException)
    d = read_jsonc(filename)

    # Content validation
    valid_solver = __validate_solver_content!(d, e)
    valid = valid_solver
    return valid ? Environment(d, e) : nothing
end