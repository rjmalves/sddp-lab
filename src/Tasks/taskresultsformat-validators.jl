# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_task_results_format_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["format"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["format"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_any_format_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_csv_format_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_parquet_format_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_any_format_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_csv_format_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_parquet_format_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_any_format_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_csv_format_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_parquet_format_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_any_format_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_csv_format_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_parquet_format_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
