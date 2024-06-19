# CLASS Convergence -----------------------------------------------------------------------

struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::StoppingCriteria
end

function Convergence(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_stopping_criteria = __build_stopping_criteria!(d, e)

    valid_internals = valid_stopping_criteria

    # Keys and types validation
    valid_keys_types = valid_internals ? __validate_convergence_keys_types!(d, e) : false

    # Content validation
    valid_content = valid_keys_types ? __validate_convergence_content!(d, e) : false

    valid = valid_internals && valid_keys_types && valid_content

    return if valid
        Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"])
    else
        nothing
    end
end

function __build_convergence!(d::Dict{String,Any}, e::CompositeException)::Bool
    convergence_d = d["convergence"]
    convergence_obj = Convergence(convergence_d, e)
    d["convergence"] = convergence_obj

    return convergence_obj !== nothing
end