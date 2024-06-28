# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_configuration_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["buses", "lines", "hydros", "thermals"]
    keys_types = [Buses, Lines, Hydros, Thermals]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_system_entity_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_entity_keys = __validate_keys!(d, ["entities"], e)
    valid_entity_types =
        valid_entity_keys &&
        __validate_key_types!(d, ["entities"], [Vector{Dict{String,Any}}], e)

    return valid_entity_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_cast_system_entity_content!(
    filename::String, e::CompositeException
)::Vector{Dict{String,Any}}
    df = read_csv(filename, e)
    valid_df = df !== nothing
    empty_df = valid_df && (nrow(df) == 0)
    # Fast check for empty dataframe
    if empty_df
        return []
    elseif valid_df
        return __dataframe_to_dict(df)
    end
end

function __validate_system_entity_file_key!(d::Dict{String,Any}, e::CompositeException)
    has_file_key = haskey(d, "file")
    valid_file_key = has_file_key && __validate_key_types!(d, ["file"], [String], e)
    return valid_file_key
end

function __validate_system_entity_entities_key!(d::Dict{String,Any}, e::CompositeException)
    valid_entities_key = __validate_keys!(d, ["entities"], e)
    valid_entities_type =
        valid_entities_key &&
        __validate_key_types!(d, ["entities"], [Vector{Dict{String,Any}}], e)
    return valid_entities_type
end

function __validate_cast_system_entity_with_file!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    entities_dict = __validate_cast_system_entity_content!(d["file"], e)
    valid_entities = entities_dict !== nothing
    d["entities"] = entities_dict

    return valid_entities
end

function __fill_default_values!(
    entities::Vector{Dict{String,Any}}, default_values::Dict{String,Any}
)
    for e in entities
        for (k, v) in e
            if v === missing
                e[k] = default_values[k]
            end
        end
    end
end

function __fill_system_entity_default_values!(d::Dict{String,Any}, e::CompositeException)
    entities = d["entities"]
    default_values = haskey(d, "params") ? d["params"] : Dict{String,Any}()
    valid = __validate_required_default_values!(d["entities"], default_values, e)
    !valid || __fill_default_values!(entities, default_values)
    return nothing
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
    valid_entities_key =
        valid_file_key || __validate_system_entity_entities_key!(entity_data, e)

    valid = false
    if valid_file_key
        valid = __validate_cast_system_entity_with_file!(entity_data, e)
    elseif valid_entities_key
        valid = true
    end

    if valid
        __fill_system_entity_default_values!(entity_data, e)
    end

    return valid
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
