# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

STUDY_KEYS = ["inputs", "engine"]
STUDY_KEY_TYPES = [InputsData, T where {T<:Engine}]
STUDY_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}, Dict{String,Any}]

function __validate_study_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = STUDY_KEYS
    keys_types = STUDY_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_study_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = STUDY_KEYS
    keys_types = STUDY_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_study_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_study_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_study_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    d["inputs"] = InputsData(d["inputs"], e)
    __build_engine!(d, e)
    valid_inputs = d["inputs"] !== nothing
    valid_engine = d["engine"] !== nothing
    return valid_inputs && valid_engine
end

function __cast_study_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_study_keys_types_before_build!(d, e)
    return valid_key_types
end
