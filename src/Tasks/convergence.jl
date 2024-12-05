# CLASS Convergence -----------------------------------------------------------------------

function Convergence(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_convergence_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_convergence_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_convergence_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_convergence_consistency!(d, e)

    return if valid_consistency
        Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"])
    else
        nothing
    end
end

function __build_convergence!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_convergence_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    convergence_d = d["convergence"]

    valid_key_types = __validate_convergence_keys_types_before_build!(convergence_d, e)
    if !valid_key_types
        return false
    end

    d["convergence"] = Convergence(convergence_d, e)
    return d["convergence"] !== nothing
end

function __cast_convergence_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
