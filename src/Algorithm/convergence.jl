# CLASS Convergence -----------------------------------------------------------------------

function Convergence(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_stopping_criteria = __build_stopping_criteria!(d, e)
    valid_internals = valid_stopping_criteria

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_convergence_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_convergence_content!(d, e)

    return if valid_content
        Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"])
    else
        nothing
    end
end

function __build_convergence!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_convergence_key = __validate_keys!(d, ["convergence"], e)
    valid_convergence_type =
        valid_convergence_key &&
        __validate_key_types!(d, ["convergence"], [Dict{String,Any}], e)
    if !valid_convergence_type
        return false
    end

    convergence_d = d["convergence"]
    convergence_obj = Convergence(convergence_d, e)
    d["convergence"] = convergence_obj

    return convergence_obj !== nothing
end