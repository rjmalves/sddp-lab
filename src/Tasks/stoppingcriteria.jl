# CLASS IterationLimit -----------------------------------------------------------------------

function IterationLimit(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_iteration_limit_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_iteration_limit_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_iteration_limit_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_iteration_limit_consistency!(d, e)

    return if valid_consistency
        IterationLimit(d["num_iterations"])
    else
        nothing
    end
end

# CLASS TimeLimit -----------------------------------------------------------------------

function TimeLimit(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_time_limit_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_time_limit_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_time_limit_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_time_limit_consistency!(d, e)

    return if valid_consistency
        TimeLimit(d["time_seconds"])
    else
        nothing
    end
end

# CLASS LowerBoundStability -----------------------------------------------------------------------

function LowerBoundStability(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_lower_bound_stability_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_lower_bound_stability_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_lower_bound_stability_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_lower_bound_stability_consistency!(d, e)

    return if valid_consistency
        LowerBoundStability(d["threshold"], d["num_iterations"])
    else
        nothing
    end
end

# SDDP METHODS --------------------------------------------------------------------------

function generate_stopping_rule(s::IterationLimit)::SDDP.AbstractStoppingRule
    return SDDP.IterationLimit(s.num_iterations)
end

function generate_stopping_rule(s::TimeLimit)::SDDP.AbstractStoppingRule
    return SDDP.TimeLimit(s.time_seconds)
end

function generate_stopping_rule(s::LowerBoundStability)::SDDP.AbstractStoppingRule
    return SDDP.BoundStalling(s.num_iterations, s.threshold)
end

# HELPERS -------------------------------------------------------------------------------------

function __build_stopping_criteria!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stopping_criteria_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "stopping_criteria", e)
end

function __cast_stopping_criteria_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
