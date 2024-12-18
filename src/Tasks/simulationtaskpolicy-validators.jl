# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

SIMULATION_TASK_POLICY_KEYS = ["path", "load", "format"]
SIMULATION_TASK_POLICY_KEY_TYPES = [String, Bool, TaskResultsFormat]
SIMULATION_TASK_POLICY_KEY_TYPES_BEFORE_BUILD = [String, Bool, Dict{String,Any}]

function __validate_simulation_task_policy_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["results"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["results"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_simulation_task_policy_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = SIMULATION_TASK_POLICY_KEYS
    keys_types = SIMULATION_TASK_POLICY_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_simulation_task_policy_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = SIMULATION_TASK_POLICY_KEYS
    keys_types = SIMULATION_TASK_POLICY_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_simulation_task_policy_path!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_simulation_task_policy_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_path = __validate_simulation_task_policy_path!(d, e)
    return valid_path
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_simulation_task_policy_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_simulation_task_policy_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_format = __build_results_format!(d, e)
    return valid_format
end
