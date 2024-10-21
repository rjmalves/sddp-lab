# CLASS TaskResults -----------------------------------------------------------------------

function TaskResults(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_results_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_results_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_results_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_results_consistency!(d, e)

    return if valid_consistency
        TaskResults(d["path"], d["save"], d["format"])
    else
        nothing
    end
end

function __build_results!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_results_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    results_d = d["results"]

    valid_key_types = __validate_results_keys_types_before_build!(results_d, e)
    if !valid_key_types
        return false
    end

    d["results"] = TaskResults(results_d, e)
    return d["results"] !== nothing
end

function __cast_results_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
