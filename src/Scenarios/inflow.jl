
# CLASS InflowScenarios -----------------------------------------------------------------------

function InflowScenarios(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_inflow_scenarios_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_inflow_scenarios_keys_types!(d, e)

    return if valid_keys_types
        InflowScenarios(d["stochastic_process"])
    else
        nothing
    end
end

# HELPERS -------------------------------------------------------------------------------------

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
    return __cast_stochastic_process_internals_from_files!(d["inflow"], e)
end