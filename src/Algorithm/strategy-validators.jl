# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_strategy_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(
        d, ["policy_graph", "horizon", "risk_measure", "convergence"], e
    )
    valid_types = __validate_key_types!(
        d,
        ["policy_graph", "horizon", "risk_measure", "convergence"],
        [
            T where {T<:PolicyGraph},
            T where {T<:Horizon},
            T where {T<:RiskMeasure},
            Convergence,
        ],
        e,
    )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_horizon_file_key!(d::Dict{String,Any}, e::CompositeException)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    has_file_key = valid_params_type && __validate_keys!(d["params"], ["file"], e)
    valid_file_key =
        has_file_key && __validate_key_types!(d["params"], ["file"], [String], e)
    return valid_file_key
end

function __validate_cast_horizon_stage_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_horizon_key = __validate_keys!(d, ["horizon"], e)
    valid_horizon_type =
        valid_horizon_key && __validate_key_types!(d, ["horizon"], [Dict{String,Any}], e)
    if !valid_horizon_type
        return false
    end

    horizon_data = d["horizon"]
    valid_file_key = __validate_horizon_file_key!(horizon_data, e)
    valid_stages = false

    if valid_file_key
        stages_dict = __validate_dataframe_content_and_cast!(
            horizon_data["params"]["file"],
            ["index", "start_date", "end_date"],
            [Integer, Date, Date],
            e,
        )
        valid_stages = stages_dict !== nothing
        horizon_data["params"]["stages"] = stages_dict
    end

    return valid_file_key && valid_stages
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

function __insert_default_values_in_dataframe!(
    df::DataFrame, default_values::Dict{String,Any}
)
    for (col, value) in default_values
        df[!, col] = replace(df[!, col], missing => value)
        disallowmissing!(df, col)
    end
end