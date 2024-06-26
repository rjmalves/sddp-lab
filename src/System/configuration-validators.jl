# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_configuration_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["buses", "lines", "hydros", "thermals"]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = if valid_keys
        __validate_key_types!(d, keys, [Buses, Lines, Hydros, Thermals], e)
    else
        false
    end
    return valid_keys && valid_types
end

function __validate_system_entity_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_entity_keys = __validate_keys!(d, ["entities"], e)
    valid_file_keys =
        valid_entity_keys ? __validate_keys!(d["entities"], ["file"], e) : false
    valid_file_types = if valid_file_keys
        __validate_key_types!(d["entities"], ["file"], [String], e)
    else
        false
    end
    return valid_entity_keys && valid_file_keys && valid_file_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_cast_system_entity_content!(
    filename::String, default_values::Dict{String,Any}, e::CompositeException
)::Union{Vector{Dict{String,Any}},Nothing}
    df = read_csv(filename, e)
    valid_df = df !== nothing
    empty_df = valid_df && (nrow(df) == 0)
    # Fast check for empty dataframe
    if empty_df
        return []
    end

    # Checks which columns demand default values
    columns, data_types = __get_dataframe_columns_for_default_value_fill(df)

    # Replaces missing values with default values
    valid = __validate_required_default_values!(default_values, columns, data_types, df, e)
    !valid || __fill_default_values!(df, default_values)
    return valid ? __dataframe_to_dict(df) : nothing
end

function __validate_system_entity_file_key!(d::Dict{String,Any}, e::CompositeException)
    valid_entities_key = __validate_keys!(d, ["entities"], e)
    valid_entities_type =
        valid_entities_key && __validate_key_types!(d, ["entities"], [Dict{String,Any}], e)
    has_file_key = valid_entities_type && __validate_keys!(d["entities"], ["file"], e)
    valid_file_key =
        has_file_key && __validate_key_types!(d["entities"], ["file"], [String], e)
    return valid_file_key
end

function __validate_system_entity_params_key!(d::Dict{String,Any}, e::CompositeException)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    return valid_params_type
end

function __validate_cast_system_entities_content!(
    d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    valid_entity_key = __validate_keys!(d, [key], e)
    valid_entity_type =
        valid_entity_key && __validate_key_types!(d, [key], [Dict{String,Any}], e)
    if !valid_entity_type
        return false
    end

    entity_data = d[key]
    valid_file_key = __validate_system_entity_file_key!(entity_data, e)
    valid_params_key = __validate_system_entity_params_key!(entity_data, e)
    valid_entities = false

    if valid_file_key && valid_params_key
        entities_dict = __validate_cast_system_entity_content!(
            entity_data["entities"]["file"], entity_data["params"], e
        )
        valid_entities = entities_dict !== nothing
        d[key] = entities_dict
    end

    return valid_file_key && valid_entities
end

function __validate_cast_buses_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return __validate_cast_system_entities_content!(d, "buses", e)
end

function __validate_cast_lines_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return __validate_cast_system_entities_content!(d, "lines", e)
end

function __validate_cast_hydros_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return __validate_cast_system_entities_content!(d, "hydros", e)
end

function __validate_cast_thermals_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return __validate_cast_system_entities_content!(d, "thermals", e)
end

# HELPER FUNCTIONS ------------------------------------------------------------------------
