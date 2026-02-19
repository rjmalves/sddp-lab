
function InflowScenarios(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_inflow_scenarios_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_inflow_scenarios_keys_types!(d, e)

    return if valid_keys_types
        InflowScenarios(d["stochastic_process"])
    else
        nothing
    end
end

function __build_inflow_scenarios!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_inflow_scenarios_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    inflow_d = d["inflow"]

    valid_key_types = __validate_inflow_scenarios_before_build_keys_types!(inflow_d, e)
    if !valid_key_types
        return false
    end

    d["inflow"] = InflowScenarios(inflow_d, e)
    return d["inflow"] !== nothing
end

function __cast_inflow_scenarios_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    sp_dict = d["inflow"]["stochastic_process"]
    if __is_multi_process_dict(sp_dict)
        valid = true
        for (key, state_dict) in sp_dict
            if state_dict isa Dict{String,Any} && haskey(state_dict, "params")
                sub_d = Dict{String,Any}("stochastic_process" => state_dict)
                valid = valid && __cast_stochastic_process_internals_from_files!(sub_d, e)
            end
        end
        return valid
    else
        return __cast_stochastic_process_internals_from_files!(d["inflow"], e)
    end
end
