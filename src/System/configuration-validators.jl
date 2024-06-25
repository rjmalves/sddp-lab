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
    df = __read_dataframe!(filename, e)
    valid_df = df !== nothing
    empty_df = valid_df && (nrow(df) == 0)
    # Fast check for empty dataframe
    if empty_df
        return []
    end

    # Checks which columns demand default values
    columns_requiring_default_values::Vector{String} = []
    columns_data_types::Vector{DataType} = []
    __extract_dataframe_columns_for_inserting_default_values!(
        df, columns_requiring_default_values, columns_data_types
    )

    # Replaces missing values with default values
    valid = __validate_required_default_values!(
        default_values, columns_requiring_default_values, columns_data_types, df, e
    )
    !valid || __insert_default_values_in_dataframe!(df, default_values)
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

function __read_dataframe!(
    filename::String, e::CompositeException
)::Union{DataFrame,Nothing}
    valid_file = __validate_file!(filename, e)
    return valid_file ? read_csv(filename) : nothing
end

function __read_validate_dataframe!(
    filename::String, cols::Vector{String}, types::Vector{DataType}, e::CompositeException
)::Union{DataFrame,Nothing}
    valid_file = __validate_file!(filename, e)
    df = valid_file ? read_csv(filename) : DataFrame()
    valid_df = __validate_columns_types_in_dataframe!(df, cols, types, e)
    return valid_df ? df : nothing
end

function __validate_dataframe_content_and_cast!(
    filename::String, cols::Vector{String}, types::Vector{DataType}, e::CompositeException
)::Union{Vector{Dict{String,Any}},Nothing}
    df = __read_validate_dataframe!(filename, cols, types, e)
    valid = df !== nothing
    return valid ? __dataframe_to_dict(df) : nothing
end

function __validate_columns_in_dataframe!(
    df::DataFrame, columns::Vector{String}, e::CompositeException
)::Bool
    valid = true
    df_columns = names(df)
    for col in columns
        column_in_df = findfirst(==(col), df_columns) !== nothing
        column_in_df ||
            push!(e, AssertionError("Column $col not found in DataFrame ($df_columns)"))
        valid = valid && column_in_df
    end
    return valid
end

function __validate_columns_types_in_dataframe!(
    df::DataFrame, columns::Vector{String}, types::Vector{DataType}, e::CompositeException
)::Bool
    valid = true
    df_columns = names(df)
    for (col, col_type) in zip(columns, types)
        column_in_df = findfirst(==(col), df_columns) !== nothing
        column_in_df ||
            push!(e, AssertionError("Column $col not found in DataFrame ($df_columns)"))
        valid = valid && column_in_df
        if column_in_df
            df_col_type = eltype(df[!, col])
            col_type_in_df = df_col_type <: col_type
            col_type_in_df || push!(
                e, AssertionError("Column $col ($df_col_type) not of type ($col_type)")
            )
            valid = valid && col_type_in_df
        end
    end
    return valid
end

function __extract_dataframe_columns_for_inserting_default_values!(
    df::DataFrame,
    columns_requiring_default_values::Vector{String},
    columns_data_types::Vector{DataType},
)
    for col in names(df)
        col_type = eltype(df[!, col])
        actual_type = nonmissingtype(col_type)
        if col_type !== actual_type
            push!(columns_requiring_default_values, col)
            real_type = actual_type === Union{} ? Any : actual_type
            push!(columns_data_types, real_type)
        end
    end
end

function __validate_required_default_values!(
    default_values::Dict{String,Any},
    columns_requiring_default_values::Vector{String},
    columns_data_types::Vector{DataType},
    df::DataFrame,
    e::CompositeException,
)::Bool
    valid_column_keys = __validate_keys!(
        default_values, columns_requiring_default_values, e
    )
    valid_column_types = if valid_column_keys
        __validate_key_types!(
            default_values, columns_requiring_default_values, columns_data_types, e
        )
    else
        false
    end
    columns_in_dataframe = __validate_columns_in_dataframe!(
        df, collect(keys(default_values)), e
    )
    return valid_column_keys && valid_column_types && columns_in_dataframe
end

function __insert_default_values_in_dataframe!(
    df::DataFrame, default_values::Dict{String,Any}
)
    for (col, value) in default_values
        df[!, col] = replace(df[!, col], missing => value)
        disallowmissing!(df, col)
    end
end
