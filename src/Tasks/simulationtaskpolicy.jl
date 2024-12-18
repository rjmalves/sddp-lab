# CLASS SimulationTaskPolicy -----------------------------------------------------------------------

function SimulationTaskPolicy(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_simulation_task_policy_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types =
        valid_internals && __validate_simulation_task_policy_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_simulation_task_policy_content!(d, e)

    # Consistency validation
    valid_consistency =
        valid_content && __validate_simulation_task_policy_consistency!(d, e)

    return if valid_consistency
        SimulationTaskPolicy(d["path"], d["load"], d["format"])
    else
        nothing
    end
end

function __build_simulation_task_policy!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_simulation_task_policy_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    policy_d = d["policy"]

    valid_key_types = __validate_simulation_task_policy_keys_types_before_build!(
        policy_d, e
    )
    if !valid_key_types
        return false
    end

    d["policy"] = SimulationTaskPolicy(policy_d, e)
    return d["policy"] !== nothing
end

function __cast_simulation_task_policy_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
