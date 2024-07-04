# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

WORK_KEYS = ["tasks"]
WORK_KEY_TYPES = [Vector{TaskDefinition}]
WORK_KEY_TYPES_BEFORE_BUILD = [Vector{Dict{String,Any}}]

function __validate_work_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = WORK_KEYS
    keys_types = WORK_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_work_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = WORK_KEYS
    keys_types = WORK_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_work_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_work_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_work_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_tasks = __build_tasks!(d, e)
    return valid_tasks
end

function __cast_work_internals_from_files!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end