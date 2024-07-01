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

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_expectation_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_expectation_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_expectation_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
