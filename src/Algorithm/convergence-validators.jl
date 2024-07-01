# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

CONVERGENCE_KEYS = ["min_iterations", "max_iterations", "stopping_criteria"]
CONVERGENCE_KEY_TYPES = [Integer, Integer, T where {T<:StoppingCriteria}]
CONVERGENCE_KEY_TYPES_BEFORE_BUILD = [Integer, Integer, Dict{String,Any}]

function __validate_convergence_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["convergence"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["convergence"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_convergence_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONVERGENCE_KEYS
    keys_types = CONVERGENCE_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_convergence_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONVERGENCE_KEYS
    keys_types = CONVERGENCE_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
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

function __validate_convergence_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_convergence_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stopping_criteria = __build_stopping_criteria!(d, e)
    return valid_stopping_criteria
end
