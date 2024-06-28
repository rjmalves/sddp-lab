# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_strategy_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["scenario_graph", "horizon", "risk_measure", "convergence"]
    keys_types = [
        T where {T<:ScenarioGraph},
        T where {T<:Horizon},
        T where {T<:RiskMeasure},
        Convergence,
    ]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_horizon_file_key!(d::Dict{String,Any}, e::CompositeException)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    has_file_key = valid_params_type && haskey(d["params"], "file")
    valid_file_key =
        has_file_key && __validate_key_types!(d["params"], ["file"], [String], e)
    return valid_file_key
end

function __validate_horizon_params_key_with_stages!(
    d::Dict{String,Any}, e::CompositeException
)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    valid_stages_in_params_key =
        valid_params_type && __validate_keys!(d["params"], ["stages"], e)
    valid_stages_in_params_type =
        valid_stages_in_params_key &&
        __validate_key_types!(d["params"], ["stages"], [Vector{Dict{String,Any}}], e)
    return valid_stages_in_params_type
end

function __validate_cast_horizon_with_file!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    df = read_csv(d["params"]["file"], e)
    valid_df = df !== nothing
    valid_stages = valid_df

    if valid_df
        stages_dict = __validate_dataframe_content_and_cast!(
            df, ["index", "start_date", "end_date"], [Integer, Date, Date], e
        )
        valid_stages = stages_dict !== nothing
        d["params"]["stages"] = stages_dict
    end
    return valid_stages
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
    valid_stages_in_params_key =
        valid_file_key || __validate_horizon_params_key_with_stages!(horizon_data, e)

    valid = false
    if valid_file_key
        valid = __validate_cast_horizon_with_file!(horizon_data, e)
    else
        valid = valid_stages_in_params_key
    end

    return valid
end

# HELPER FUNCTIONS ------------------------------------------------------------------------
