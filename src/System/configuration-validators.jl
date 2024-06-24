# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_configuration_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["buses", "lines", "hydros", "thermals"], e)
    valid_types = __validate_key_types!(
        d, ["buses", "lines", "hydros", "thermals"], [Buses, Lines, Hydros, Thermals], e
    )
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

function __validate_required_default_values!(
    d::Dict{String,Any},
    columns_requiring_default_values::Vector{String},
    columns_data_types::Vector{DataType},
    df::DataFrame,
    default_values::Dict{String,Any},
    e::CompositeException,
)::Bool
    valid_default_values_keys = __validate_keys!(d, ["params"], e)
    !valid_default_values_keys || merge!(default_values, d["params"])

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

function __validate_system_entity_content!(
    df::DataFrame, d::Dict{String,Any}, e::CompositeException
)::Bool
    # Fast check for empty dataframe
    if nrow(df) == 0
        return false
    end

    # Checks which columns demand default values
    columns_requiring_default_values::Vector{String} = []
    columns_data_types::Vector{DataType} = []
    __extract_columns_for_default_values!(
        df, columns_requiring_default_values, columns_data_types
    )

    # Replaces missing values with default values
    default_values = Dict{String,Any}()
    valid = __validate_required_default_values!(
        d, columns_requiring_default_values, columns_data_types, df, default_values, e
    )
    !valid || __insert_default_values!(df, default_values)
    return valid
end

function __validate_system_entities_content!(
    d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    entities = d[key]
    df = __read_entity_dataframe!(entities, e)
    valid = __validate_system_entity_content!(df, entities, e)
    if valid
        d[key] = __dataframe_to_dict(df)
    else
        d[key] = []
    end
    return valid
end

function __validate_buses_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    return __validate_system_entities_content!(d, "buses", e)
end

function __validate_lines_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    return __validate_system_entities_content!(d, "lines", e)
end

function __validate_hydros_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    return __validate_system_entities_content!(d, "hydros", e)
end

function __validate_thermals_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    return __validate_system_entities_content!(d, "thermals", e)
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __read_entity_dataframe!(d::Dict{String,Any}, e::CompositeException)::DataFrame
    valid_keys_types = __validate_system_entity_keys_types!(d, e)
    filename = valid_keys_types ? d["entities"]["file"] : ""
    valid_file = __validate_file!(filename, e)
    df = valid_file ? read_csv(filename) : DataFrame()
    return df
end

function __extract_columns_for_default_values!(
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

function __insert_default_values!(df::DataFrame, default_values::Dict{String,Any})
    for (col, value) in default_values
        df[!, col] = replace(df[!, col], missing => value)
        disallowmissing!(df, col)
    end
end
