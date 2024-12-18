# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_parallel_scheme_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["parallel_scheme"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_serial_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_serial_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_serial_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_serial_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_asynchronous_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
