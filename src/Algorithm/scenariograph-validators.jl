# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_regular_scenario_graph_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["discount_rate"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["discount_rate"], [Real], e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_regular_scenario_graph_discount_rate!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    discount_rate = d["discount_rate"]
    positive = discount_rate > 0
    positive || push!(
        e,
        AssertionError("Scenario graph - discount rate ($discount_rate) must be positive"),
    )
    less_equal_one = discount_rate <= 1
    less_equal_one || push!(
        e,
        AssertionError("Scenario graph - discount rate ($discount_rate) must be <= 1"),
    )
    return positive && less_equal_one
end

function __validate_regular_scenario_graph_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_discount_rate = __validate_regular_scenario_graph_discount_rate!(d, e)
    return valid_discount_rate
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------
