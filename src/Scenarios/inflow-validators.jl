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
    valid_keys = __validate_keys!(d, INFLOW_SCENARIOS_KEYS, e)
    if !valid_keys
        return false
    end
    sp = d["stochastic_process"]
    valid = sp isa AbstractStochasticProcess
    if !valid
        push!(
            e,
            ErrorException(
                "Key 'stochastic_process' ($(typeof(sp))) can't be converted to AbstractStochasticProcess",
            ),
        )
    end
    return valid
end

function __validate_inflow_scenarios_before_build_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = INFLOW_SCENARIOS_KEYS
    valid_keys = __validate_keys!(d, keys, e)
    if !valid_keys
        return false
    end
    sp = d["stochastic_process"]
    valid = sp isa Dict{String,Any}
    if !valid
        push!(
            e, ErrorException("Key 'stochastic_process' must be a Dict, got $(typeof(sp))")
        )
    end
    return valid
end

function __build_inflow_scenarios_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __build_stochastic_process!(d, e)
end

function __validate_stochastic_process_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["stochastic_process"]
    valid_keys = __validate_keys!(d, keys, e)
    if !valid_keys
        return false
    end
    sp = d["stochastic_process"]
    valid = sp isa Dict{String,Any}
    if !valid
        push!(
            e,
            ErrorException(
                "Key 'stochastic_process' must be a Dict{String,Any}, got $(typeof(sp))"
            ),
        )
    end
    return valid
end

function __build_stochastic_process!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stochastic_process_keys_types!(d, e)
    if !valid_key_types
        return false
    end

    result = __single_object_factory(StochasticProcess, d["stochastic_process"], e)
    valid = result !== nothing
    if valid
        d["stochastic_process"] = result
    end
    return valid
end
