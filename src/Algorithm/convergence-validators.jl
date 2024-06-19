# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_convergence_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(
        d, ["min_iterations", "max_iterations", "stopping_criteria"], e
    )
    valid_types =
        valid_keys || __validate_key_types!(
            d,
            ["min_iterations", "max_iterations", "stopping_criteria"],
            [Integer, Integer, <:StoppingCriteria],
            e,
        )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_convergence_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    min_iterations = d["min_iterations"]
    max_iterations = d["max_iterations"]
    positive_min = min_iterations > 0
    positive_max = max_iterations > 0
    max_greater_min = max_iterations >= min_iterations
    positive_min || push!(
        e,
        AssertionError("Convergence - min_iterations ($min_iterations) must be positive"),
    )
    positive_max || push!(
        e,
        AssertionError("Convergence - max_iterations ($max_iterations) must be positive"),
    )
    max_greater_min || push!(
        e,
        AssertionError(
            "Convergence - max_iterations ($max_iterations) must be >= min_iterations ($min_iterations)",
        ),
    )
    return positive_min && positive_max && max_greater_min
end

function __validate_convergence_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_iterations = __validate_convergence_iterations!(d, e)
    return valid_iterations
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------
