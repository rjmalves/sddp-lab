# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_strategy_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["policy_graph", "risk_measure", "convergence"], e)
    valid_types = __validate_key_types!(
        d,
        ["policy_graph", "risk_measure", "convergence"],
        [T where {T<:PolicyGraph}, T where {T<:RiskMeasure}, Convergence],
        e,
    )
    return valid_keys && valid_types
end
