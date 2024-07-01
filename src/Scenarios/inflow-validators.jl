# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

INFLOW_SCENARIOS_KEYS = ["stochastic_process"]
INFLOW_SCENARIOS_KEY_TYPES = [T where {T<:AbstractStochasticProcess}]
INFLOW_SCENARIOS_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}]

function __validate_inflow_scenarios_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["inflow"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_inflow_scenarios_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = INFLOW_SCENARIOS_KEYS
    keys_types = INFLOW_SCENARIOS_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_inflow_scenarios_before_build_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = INFLOW_SCENARIOS_KEYS
    keys_types = INFLOW_SCENARIOS_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_inflow_scenarios_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_inflow_scenarios_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -------------------------------------------------------------------------------------

function __build_inflow_scenarios_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stochastic_process = __build_stochastic_process!(d, e)
    return valid_stochastic_process
end

function __validate_stochastic_process_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["stochastic_process"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __build_stochastic_process!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stochastic_process_keys_types!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(StochasticProcess, d, "stochastic_process", e)
end

# CASTING FROM FILES ------------------------------------------------------------------------

function __validate_inflow_file_key!(d::Dict{String,Any}, e::CompositeException)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    has_file_key = valid_params_type && haskey(d["params"], "file")
    valid_file_key =
        has_file_key && __validate_key_types!(d["params"], ["file"], [String], e)
    return valid_file_key
end

function __validate_inflow_params_key_with_values!(
    d::Dict{String,Any}, e::CompositeException
)
    valid_params_key = __validate_keys!(d, ["params"], e)
    valid_params_type =
        valid_params_key && __validate_key_types!(d, ["params"], [Dict{String,Any}], e)
    valid_values_in_params_key =
        valid_params_type &&
        __validate_keys!(d["params"], ["marginal_models", "copulas"], e)
    valid_values_in_params_type =
        valid_values_in_params_key && __validate_key_types!(
            d["params"],
            ["marginal_models", "copulas"],
            [Vector{Dict{String,Any}}, Vector{Dict{String,Any}}],
            e,
        )
    return valid_values_in_params_type
end

function __validate_cast_inflow_with_file!(d::Dict{String,Any}, e::CompositeException)::Bool
    process_data = read_jsonc(d["params"]["file"], e)
    valid_process = process_data !== nothing
    if valid_process
        merge!(d["params"], process_data)
    end
    return valid_process
end
