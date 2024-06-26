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
    df = valid_file_key ? read_csv(horizon_data["params"]["file"], e) : nothing

    valid_df = df !== nothing

    valid_stages = valid_df

    if valid_df
        stages_dict = __validate_dataframe_content_and_cast!(
            df, ["index", "start_date", "end_date"], [Integer, Date, Date], e
        )
        valid_stages = stages_dict !== nothing
        horizon_data["params"]["stages"] = stages_dict
    end

    return valid_file_key && valid_stages
end

# HELPER FUNCTIONS ------------------------------------------------------------------------
