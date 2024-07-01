
# CLASS InflowScenarios -----------------------------------------------------------------------

function InflowScenarios(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_inflow_scenarios_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_inflow_scenarios_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_inflow_scenarios_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_inflow_scenarios_consistency!(d, e)

    return if valid_consistency
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
    inflow_d = d["inflow"]
    valid = __cast_stochastic_process_internals_from_files!(inflow_d, e)
    return valid
end