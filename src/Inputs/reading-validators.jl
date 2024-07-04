# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

READING_KEYS = ["path", "files"]
READING_KEY_TYPES = [String, Files]
READING_KEY_TYPES_BEFORE_BUILD = [String, Dict{String,Any}]

function __validate_reading_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["inputs"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["inputs"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_reading_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = READING_KEYS
    keys_types = READING_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_reading_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = READING_KEYS
    keys_types = READING_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_reading_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_reading_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_reading_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    curdir = pwd()
    valid_directory = __validate_directory!(d["path"], e)
    valid_directory && cd(d["path"])
    valid_files = valid_directory && __build_files!(d, e)
    cd(curdir)
    return valid_files
end

function __cast_reading_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end