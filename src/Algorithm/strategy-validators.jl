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

function __validate_horizon_content_with_file!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    df = __read_dataframe!(horizon_data["file"], e)
    valid = __validate_columns_types_in_dataframe!(
        df,
        ["index", "start_date", "end_date"],
        [Integer, Union{DateTime,Date}, Union{DateTime,Date}],
        e,
    )
    if valid
        d["stages"] = __dataframe_to_dict(df)
    else
        d["stages"] = []
    end
    return valid
end

function __validate_horizon_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    horizon_data = d["horizon"]

    valid_params_key = __validate_keys!(horizon_data, ["params"], e)
    valid_params_type =
        valid_params_key &&
        __validate_key_types!(horizon_data, ["params"], [Dict{String,Any}], e)
    has_file_key =
        valid_params_type && __validate_keys!(horizon_data["params"], ["file"], e)

    # TODO - validate if file exists

    if has_file_key
        return __validate_horizon_content_with_file!(horizon_data["params"], e)
    else
        return valid_params_type
    end
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __read_dataframe!(d::Dict{String,Any}, e::CompositeException)::DataFrame
    valid_keys_types = __validate_system_entity_keys_types!(d, e)
    filename = valid_keys_types ? d["params"]["file"] : ""
    valid_file = __validate_file!(filename, e)
    df = valid_file ? read_csv(filename) : DataFrame()
    return df
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
            col_type_in_df = eltype(df[!, col]) == col_type
            col_type_in_df ||
                push!(e, AssertionError("Column $col not of type ($col_type)"))
            valid = valid && col_type_in_df
        end
    end
    return valid
end
