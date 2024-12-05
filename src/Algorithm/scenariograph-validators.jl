# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_scenario_graph_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["scenario_graph"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["scenario_graph"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_regular_scenario_graph_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["discount_rate"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["discount_rate"], [Real], e)
    return valid_types
end

function __validate_cyclic_scenario_graph_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(
        d, ["discount_rate", "cycle_length", "cycle_stage", "max_depth"], e
    )
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["discount_rate", "cycle_length", "cycle_stage", "max_depth"],
            [Real, Integer, Integer, Integer],
            e,
        )
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

function __validate_cyclic_scenario_graph_discount_rate!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    discount_rate = d["discount_rate"]
    positive = discount_rate > 0
    positive || push!(
        e,
        AssertionError("Scenario graph - discount rate ($discount_rate) must be positive"),
    )
    less_equal_one = discount_rate < 1
    less_equal_one || push!(
        e, AssertionError("Scenario graph - discount rate ($discount_rate) must be < 1")
    )
    return positive && less_equal_one
end

function __validate_cyclic_scenario_graph_cycle_length!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    cycle_length = d["cycle_length"]
    positive = cycle_length > 0
    positive || push!(
        e,
        AssertionError("Scenario graph - cycle_length ($cycle_length) must be positive"),
    )
    return positive
end

function __validate_cyclic_scenario_graph_cycle_stage!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    cycle_stage = d["cycle_stage"]
    positive = cycle_stage > 0
    positive || push!(
        e,
        AssertionError("Scenario graph - cycle_stage ($cycle_stage) must be positive"),
    )
    return positive
end

function __validate_cyclic_scenario_graph_max_depth!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    max_depth = d["max_depth"]
    cycle_stage = d["cycle_stage"]
    cycle_length = d["cycle_length"]
    positive = max_depth > 0
    positive ||
        push!(e, AssertionError("Scenario graph - max_depth ($max_depth) must be positive"))
    containts_at_least_one_cycle = max_depth >= (cycle_stage + cycle_length - 1)
    containts_at_least_one_cycle || push!(
        e,
        AssertionError(
            "Scenario graph - max_depth ($max_depth) must contain at least one cycle"
        ),
    )
    return positive && containts_at_least_one_cycle
end

function __validate_cyclic_scenario_graph_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_discount_rate = __validate_cyclic_scenario_graph_discount_rate!(d, e)
    valid_cycle_length = __validate_cyclic_scenario_graph_cycle_length!(d, e)
    valid_cycle_stage = __validate_cyclic_scenario_graph_cycle_stage!(d, e)
    valid_max_depth = __validate_cyclic_scenario_graph_max_depth!(d, e)
    return valid_discount_rate && valid_cycle_length && valid_cycle_stage && valid_max_depth
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_regular_scenario_graph_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_cyclic_scenario_graph_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_regular_scenario_graph_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_cyclic_scenario_graph_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
