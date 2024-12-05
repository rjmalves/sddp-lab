# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_stopping_criteria_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["stopping_criteria"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["stopping_criteria"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_iteration_limit_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["num_iterations"]
    keys_types = [Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_time_limit_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["time_seconds"]
    keys_types = [Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_lower_bound_stability_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["threshold", "num_iterations"]
    keys_types = [Real, Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_iteration_limit_num_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    num_iterations = d["num_iterations"]
    positive = num_iterations > 0
    positive || push!(
        e,
        AssertionError(
            "Stopping criteria - num_iterations ($num_iterations) must be positive"
        ),
    )
    return positive
end

function __validate_time_limit_time_seconds!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    time_seconds = d["time_seconds"]
    positive = time_seconds > 0
    positive || push!(
        e,
        AssertionError("Stopping criteria - time_seconds ($time_seconds) must be positive"),
    )
    return positive
end

function __validate_lower_bound_stability_threshold!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    threshold = d["threshold"]
    positive = threshold > 0
    positive || push!(
        e, AssertionError("Stopping criteria - threshold ($threshold) must be positive")
    )
    less_equal_one = threshold <= 1
    less_equal_one ||
        push!(e, AssertionError("Stopping criteria - threshold ($threshold) must be <= 1"))
    return positive && less_equal_one
end

function __validate_lower_bound_stability_num_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    num_iterations = d["num_iterations"]
    positive = num_iterations > 0
    positive || push!(
        e,
        AssertionError(
            "Stopping criteria - num_iterations ($num_iterations) must be positive"
        ),
    )
    return positive
end

function __validate_iteration_limit_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_num_iterations = __validate_iteration_limit_num_iterations!(d, e)
    return valid_num_iterations
end

function __validate_time_limit_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_time_seconds = __validate_time_limit_time_seconds!(d, e)
    return valid_time_seconds
end

function __validate_lower_bound_stability_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_threshold = __validate_lower_bound_stability_threshold!(d, e)
    valid_num_iterations = __validate_lower_bound_stability_num_iterations!(d, e)
    return valid_threshold && valid_num_iterations
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_iteration_limit_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_time_limit_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_lower_bound_stability_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_iteration_limit_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_time_limit_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_lower_bound_stability_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
