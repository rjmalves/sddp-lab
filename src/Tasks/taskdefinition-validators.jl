# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

ECHO_KEYS = ["results"]
ECHO_KEY_TYPES = [Results]
ECHO_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}]

POLICY_KEYS = ["convergence", "results"]
POLICY_KEY_TYPES = [Convergence, Results]
POLICY_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}, Dict{String,Any}]

SIMULATION_KEYS = ["num_simulated_series", "policy_path", "results"]
SIMULATION_KEY_TYPES = [Integer, String, Results]
SIMULATION_KEY_TYPES_BEFORE_BUILD = [Integer, String, Dict{String,Any}]

function __validate_tasks_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["tasks"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["tasks"], [Vector{Dict{String,Any}}], e)
    return valid_types
end

function __validate_echo_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ECHO_KEYS
    keys_types = ECHO_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_echo_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ECHO_KEYS
    keys_types = ECHO_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_policy_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = POLICY_KEYS
    keys_types = POLICY_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_policy_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = POLICY_KEYS
    keys_types = POLICY_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_simulation_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = SIMULATION_KEYS
    keys_types = SIMULATION_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_simulation_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = SIMULATION_KEYS
    keys_types = SIMULATION_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_echo_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_policy_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_simulation_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_echo_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_policy_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_simulation_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_echo_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_results = __build_results!(d, e)
    return valid_results
end

function __build_policy_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_convergence = __build_convergence!(d, e)
    valid_risk_measure = __build_risk_measure!(d, e)
    valid_parallel_scheme = __build_parallel_scheme!(d, e)
    valid_results = __build_results!(d, e)
    return valid_convergence && valid_risk_measure && valid_parallel_scheme && valid_results
end

function __build_simulation_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_parallel_scheme = __build_parallel_scheme!(d, e)
    valid_results = __build_results!(d, e)
    return valid_parallel_scheme && valid_results
end
