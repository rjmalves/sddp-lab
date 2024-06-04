# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_configuration_keys_types!(d::Dict{String,Any}, e::CompositeException)
    __validate_keys!(d, ["buses", "lines", "hydros", "thermals"], e)
    __validate_key_types!(
        d,
        ["buses", "lines", "hydros", "thermals"],
        [Dict{String,Any}, Dict{String,Any}, Dict{String,Any}, Dict{String,Any}],
        e,
    )
    return __throw_composite_exception_if_any(e)
end

function __validate_system_entity_keys_types!(d::Dict{String,Any}, e::CompositeException)
    __validate_keys!(d, ["entities"], e)
    return __throw_composite_exception_if_any(e)

    __validate_keys!(d["entities"], ["file"], e)
    __validate_key_types!(d["entities"], ["file"], [String], e)
    return __throw_composite_exception_if_any(e)
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_system_entity_content!(
    df::DataFrame, d::Dict{String,Any}, e::CompositeException
)
    if nrow(df) == 0
        return nothing
    end

    # Checks which columns demand default values
    columns_requiring_default_values::Vector{String} = []
    columns_data_types::Vector{DataType} = []
    for col in names(df)
        col_type = eltype(df[!, col])
        actual_type = nonmissingtype(col_type)
        if col_type !== actual_type
            push!(columns_requiring_default_values, col)
            real_type = actual_type === Union{} ? Any : actual_type
            push!(columns_data_types, real_type)
        end
    end

    __validate_keys!(d, ["params"], e)
    __throw_composite_exception_if_any(e)

    default_values = d["params"]

    # Replaces missing values with default values
    __validate_keys!(default_values, columns_requiring_default_values, e)
    __validate_key_types!(
        default_values, columns_requiring_default_values, columns_data_types, e
    )
    for col in columns_requiring_default_values
        df[!, col] = replace(df[!, col], missing => default_values[col])
        disallowmissing!(df, col)
    end
end

function __validate_system_entities_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    df = __read_entity_dataframe!(d, e)
    __validate_system_entity_content!(df, d, e)
    return __dataframe_to_dict(df)
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __read_entity_dataframe!(d::Dict{String,Any}, e::CompositeException)::DataFrame
    __validate_system_entity_keys_types!(d, e)

    filename = d["entities"]["file"]

    __validate_file!(filename, e)
    __throw_composite_exception_if_any(e)

    df = read_csv(filename)
    return df
end
