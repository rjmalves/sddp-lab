INFLOW_SCENARIOS_KEYS = ["stochastic_process"]
INFLOW_SCENARIOS_KEY_TYPES = [Dict{Int,T} where {T<:AbstractStochasticProcess}]
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
    valid = sp isa Dict{Int,<:AbstractStochasticProcess}
    if !valid
        push!(e, ErrorException(
            "Key 'stochastic_process' ($(typeof(sp))) can't be converted to Dict{Int, AbstractStochasticProcess}"
        ))
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
        push!(e, ErrorException(
            "Key 'stochastic_process' must be a Dict, got $(typeof(sp))"
        ))
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
        push!(e, ErrorException(
            "Key 'stochastic_process' must be a Dict{String,Any}, got $(typeof(sp))"
        ))
    end
    return valid
end

# Returns true when stochastic_process is a dict-of-dicts (Markov format) rather than a
# single kind/params dict (legacy format). Markov keys are string integers ("1", "2", ...).
function __is_multi_process_dict(sp_dict::Dict{String,Any})::Bool
    return !haskey(sp_dict, "kind") && !haskey(sp_dict, "params")
end

function __build_stochastic_process!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stochastic_process_keys_types!(d, e)
    if !valid_key_types
        return false
    end

    sp_dict = d["stochastic_process"]

    if __is_multi_process_dict(sp_dict)
        return __build_multi_stochastic_process!(d, sp_dict, e)
    else
        return __build_single_stochastic_process!(d, sp_dict, e)
    end
end

function __build_single_stochastic_process!(
    d::Dict{String,Any}, sp_dict::Dict{String,Any}, e::CompositeException
)::Bool
    result = __single_object_factory(StochasticProcess, sp_dict, e)
    valid = result !== nothing
    if valid
        d["stochastic_process"] = Dict{Int,AbstractStochasticProcess}(1 => result)
    end
    return valid
end

function __build_multi_stochastic_process!(
    d::Dict{String,Any}, sp_dict::Dict{String,Any}, e::CompositeException
)::Bool
    processes = Dict{Int,AbstractStochasticProcess}()
    valid = true

    for key in keys(sp_dict)
        parsed_key = tryparse(Int, key)
        if parsed_key === nothing
            push!(e, AssertionError(
                "Markov stochastic_process key '$key' must be a string integer (e.g. \"1\", \"2\")"
            ))
            valid = false
            continue
        end

        state_dict = sp_dict[key]
        if !(state_dict isa Dict{String,Any})
            push!(e, AssertionError(
                "Markov stochastic_process[$key] must be a Dict with 'kind' and 'params', got $(typeof(state_dict))"
            ))
            valid = false
            continue
        end

        process = __single_object_factory(StochasticProcess, state_dict, e)
        if process !== nothing
            processes[parsed_key] = process
        else
            valid = false
        end
    end

    if valid
        d["stochastic_process"] = processes
    end
    return valid
end
