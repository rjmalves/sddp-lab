# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_outputs_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["path", "policy", "simulation", "plots"]
    types = [String, Bool, Bool, Bool]

    valid_keys = __validate_keys!(d, keys, e)
    valid_key_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_key_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_outputs!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_outputs_keys_types!(d, e)
    valid_directory = valid_key_types && __validate_directory!(d["path"], e)
    # Creates directory if missing
    valid_directory || mkdir(d["path"])

    return valid_key_types
end
