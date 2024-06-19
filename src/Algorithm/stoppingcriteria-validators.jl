# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_lower_bound_stability_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["threshold", "num_iterations"], e)
    valid_types = __validate_key_types!(
        d, ["threshold", "num_iterations"], [Real, Integer], e
    )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

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

function __validate_lower_bound_stability_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_threshold = __validate_lower_bound_stability_threshold!(d, e)
    valid_num_iterations = __validate_lower_bound_stability_num_iterations!(d, e)
    return valid_threshold && valid_num_iterations
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------
