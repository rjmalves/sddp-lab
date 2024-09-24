# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

RESULTS_KEYS = ["path", "save"]
RESULTS_KEY_TYPES = [String, Bool]

function __validate_results_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["results"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["results"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_results_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = RESULTS_KEYS
    keys_types = RESULTS_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_results_path!(d::Dict{String,Any}, e::CompositeException)::Bool
    # Create dir
    return true
end

function __validate_results_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_path = __validate_results_path!(d, e)
    return valid_path
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_results_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_results_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
