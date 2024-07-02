# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

STRATEGY_KEYS = ["scenario_graph", "horizon", "risk_measure", "convergence"]
STRATEGY_KEY_TYPES = [
    T where {T<:ScenarioGraph}, T where {T<:Horizon}, T where {T<:RiskMeasure}, Convergence
]
STRATEGY_KEY_TYPES_BEFORE_BUILD = [
    Dict{String,Any}, Dict{String,Any}, Dict{String,Any}, Dict{String,Any}
]

function __validate_strategy_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = STRATEGY_KEYS
    keys_types = STRATEGY_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_strategy_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = STRATEGY_KEYS
    keys_types = STRATEGY_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_strategy_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_strategy_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_strategy_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_scenario_graph = __build_scenario_graph!(d, e)
    valid_horizon = __build_horizon!(d, e)
    valid_risk_measure = __build_risk_measure!(d, e)
    valid_convergence = __build_convergence!(d, e)
    return valid_scenario_graph && valid_horizon && valid_risk_measure && valid_convergence
end

function __cast_strategy_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_strategy_keys_types_before_build!(d, e)
    valid_scenario_graph =
        valid_key_types && __cast_scenario_graph_internals_from_files!(d, e)
    valid_horizon = valid_key_types && __cast_horizon_internals_from_files!(d, e)
    valid_risk_measure = valid_key_types && __cast_risk_measure_internals_from_files!(d, e)
    valid_convergence = valid_key_types && __cast_convergence_internals_from_files!(d, e)
    return valid_scenario_graph && valid_horizon && valid_risk_measure && valid_convergence
end