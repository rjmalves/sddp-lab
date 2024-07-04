# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

ENTRYPOINT_KEYS = ["inputs"]
ENTRYPOINT_KEY_TYPES = [Reading]
ENTRYPOINT_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}]

function __validate_entrypoint_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ENTRYPOINT_KEYS
    keys_types = ENTRYPOINT_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_entrypoint_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ENTRYPOINT_KEYS
    keys_types = ENTRYPOINT_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_entrypoint_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_entrypoint_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_entrypoint_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    d["inputs"] = Reading(d["inputs"], e)
    valid_inputs = d["inputs"] !== nothing
    return valid_inputs
end

function __cast_entrypoint_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_entrypoint_keys_types_before_build!(d, e)
    return valid_key_types
end