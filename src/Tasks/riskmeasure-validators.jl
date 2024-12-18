# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_risk_measure_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["risk_measure"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["risk_measure"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_expectation_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_worstcase_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["alpha"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["alpha"], [Real], e)
    return valid_types
end

function __validate_cvar_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["alpha", "lambda"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["alpha", "lambda"], [Real, Real], e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_expectation_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_worstcase_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_alpha!(d::Dict{String,Any}, e::CompositeException)::Bool
    alpha = d["alpha"]
    positive = alpha >= 0
    less_than_one = alpha <= 1
    in_range = positive && less_than_one
    in_range || push!(e, AssertionError("Risk measure - alpha ($alpha) must be in [0, 1]"))
    return in_range
end

function __validate_avar_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_alpha = __validate_avar_alpha!(d, e)
    return valid_alpha
end

function __validate_cvar_alpha!(d::Dict{String,Any}, e::CompositeException)::Bool
    alpha = d["alpha"]
    positive = alpha >= 0
    less_than_one = alpha <= 1
    in_range = positive && less_than_one
    in_range || push!(e, AssertionError("Risk measure - alpha ($alpha) must be in [0, 1]"))
    return in_range
end

function __validate_cvar_lambda!(d::Dict{String,Any}, e::CompositeException)::Bool
    lambda = d["lambda"]
    positive = lambda >= 0
    less_than_one = lambda <= 1
    in_range = positive && less_than_one
    in_range ||
        push!(e, AssertionError("Risk measure - lambda ($lambda) must be in [0, 1]"))
    return in_range
end

function __validate_cvar_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_alpha = __validate_cvar_alpha!(d, e)
    valid_lambda = __validate_cvar_lambda!(d, e)
    return valid_alpha && valid_lambda
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_expectation_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_worstcase_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_cvar_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_expectation_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_worstcase_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_avar_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_cvar_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
