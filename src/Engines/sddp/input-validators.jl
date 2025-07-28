# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_stopping_criteria_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["stopping_criteria"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["stopping_criteria"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_iteration_limit_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["num_iterations"]
    keys_types = [Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_time_limit_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["time_seconds"]
    keys_types = [Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_lower_bound_stability_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["threshold", "num_iterations"]
    keys_types = [Real, Integer]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

CONVERGENCE_KEYS = ["min_iterations", "max_iterations", "stopping_criteria"]
CONVERGENCE_KEY_TYPES = [Integer, Integer, T where {T<:StoppingCriteria}]
CONVERGENCE_KEY_TYPES_BEFORE_BUILD = [Integer, Integer, Dict{String,Any}]

function __validate_convergence_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["convergence"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["convergence"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_convergence_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONVERGENCE_KEYS
    keys_types = CONVERGENCE_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_convergence_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONVERGENCE_KEYS
    keys_types = CONVERGENCE_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_parallel_scheme_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["parallel_scheme"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_serial_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_risk_measure_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["risk_measure"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["risk_measure"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_expectation_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_worstcase_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["alpha"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["alpha"], [Real], e)
    return valid_types
end

function __validate_cvar_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["alpha", "lambda"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["alpha", "lambda"], [Real, Real], e)
    return valid_types
end

function __validate_sddp_policy_task_definition_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["policy"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["policy"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_sddp_policy_task_definition_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["convergence", "risk_measure", "parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["convergence", "risk_measure", "parallel_scheme"],
            [Dict{String,Any}, Dict{String,Any}, Dict{String,Any}],
            e,
        )
    return valid_types
end

function __validate_sddp_policy_task_definition_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["convergence", "risk_measure", "parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["convergence", "risk_measure", "parallel_scheme"],
            [Convergence, T where {T<:RiskMeasure}, T where {T<:ParallelScheme}],
            e,
        )
    return valid_types
end

function __validate_sddp_simulation_task_definition_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["simulation"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["simulation"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_sddp_simulation_task_definition_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["num_simulated_series", "parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(
            d, ["num_simulated_series", "parallel_scheme"], [Integer, Dict{String,Any}], e
        )
    return valid_types
end

function __validate_sddp_simulation_task_definition_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["num_simulated_series", "parallel_scheme"], e)
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["num_simulated_series", "parallel_scheme"],
            [Integer, T where {T<:ParallelScheme}],
            e,
        )
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_iteration_limit_num_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    num_iterations = d["num_iterations"]
    positive = num_iterations > 0
    positive || push!(
        e,
        AssertionError(
            "Stopping criteria - num_iterations ($num_iterations) must be positive"
        ),
    )
    return positive
end

function __validate_time_limit_time_seconds!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    time_seconds = d["time_seconds"]
    positive = time_seconds > 0
    positive || push!(
        e,
        AssertionError("Stopping criteria - time_seconds ($time_seconds) must be positive"),
    )
    return positive
end

function __validate_lower_bound_stability_threshold!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    threshold = d["threshold"]
    positive = threshold > 0
    positive || push!(
        e, AssertionError("Stopping criteria - threshold ($threshold) must be positive")
    )
    less_equal_one = threshold <= 1
    less_equal_one ||
        push!(e, AssertionError("Stopping criteria - threshold ($threshold) must be <= 1"))
    return positive && less_equal_one
end

function __validate_lower_bound_stability_num_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    num_iterations = d["num_iterations"]
    positive = num_iterations > 0
    positive || push!(
        e,
        AssertionError(
            "Stopping criteria - num_iterations ($num_iterations) must be positive"
        ),
    )
    return positive
end

function __validate_iteration_limit_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_num_iterations = __validate_iteration_limit_num_iterations!(d, e)
    return valid_num_iterations
end

function __validate_time_limit_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_time_seconds = __validate_time_limit_time_seconds!(d, e)
    return valid_time_seconds
end

function __validate_lower_bound_stability_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_threshold = __validate_lower_bound_stability_threshold!(d, e)
    valid_num_iterations = __validate_lower_bound_stability_num_iterations!(d, e)
    return valid_threshold && valid_num_iterations
end

function __validate_convergence_iterations!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    min_iterations = d["min_iterations"]
    max_iterations = d["max_iterations"]
    positive_min = min_iterations > 0
    positive_max = max_iterations > 0
    max_greater_min = max_iterations >= min_iterations
    positive_min || push!(
        e,
        AssertionError("Convergence - min_iterations ($min_iterations) must be positive"),
    )
    positive_max || push!(
        e,
        AssertionError("Convergence - max_iterations ($max_iterations) must be positive"),
    )
    max_greater_min || push!(
        e,
        AssertionError(
            "Convergence - max_iterations ($max_iterations) must be >= min_iterations ($min_iterations)",
        ),
    )
    return positive_min && positive_max && max_greater_min
end

function __validate_convergence_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_iterations = __validate_convergence_iterations!(d, e)
    return valid_iterations
end

function __validate_serial_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_expectation_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_worstcase_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_alpha!(d::Dict{String,Any}, e::CompositeException)::Bool
    alpha = d["alpha"]
    positive = alpha >= 0
    less_than_one = alpha <= 1
    in_range = positive && less_than_one
    in_range || push!(e, AssertionError("Risk measure - alpha ($alpha) must be in [0, 1]"))
    return in_range
end

function __validate_avar_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_alpha = __validate_avar_alpha!(d, e)
    return valid_alpha
end

function __validate_cvar_alpha!(d::Dict{String,Any}, e::CompositeException)::Bool
    alpha = d["alpha"]
    positive = alpha >= 0
    less_than_one = alpha <= 1
    in_range = positive && less_than_one
    in_range || push!(e, AssertionError("Risk measure - alpha ($alpha) must be in [0, 1]"))
    return in_range
end

function __validate_cvar_lambda!(d::Dict{String,Any}, e::CompositeException)::Bool
    lambda = d["lambda"]
    positive = lambda >= 0
    less_than_one = lambda <= 1
    in_range = positive && less_than_one
    in_range ||
        push!(e, AssertionError("Risk measure - lambda ($lambda) must be in [0, 1]"))
    return in_range
end

function __validate_cvar_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_alpha = __validate_cvar_alpha!(d, e)
    valid_lambda = __validate_cvar_lambda!(d, e)
    return valid_alpha && valid_lambda
end

function __validate_sddp_policy_task_definition_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_sddp_simulation_task_definition_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_iteration_limit_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_time_limit_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_lower_bound_stability_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_convergence_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_serial_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_asynchronous_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_expectation_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_worstcase_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_avar_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_cvar_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_sddp_policy_task_definition_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __validate_sddp_simulation_task_definition_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_iteration_limit_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_time_limit_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_lower_bound_stability_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_convergence_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stopping_criteria = __build_stopping_criteria!(d, e)
    return valid_stopping_criteria
end

function __build_serial_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_asynchronous_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_expectation_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_worstcase_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_avar_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_cvar_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_sddp_policy_task_definition_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stopping_criteria = __build_convergence!(d, e)
    valid_risk_measure = __build_risk_measure!(d, e)
    valid_parallel_schema = __build_parallel_scheme!(d, e)
    return valid_stopping_criteria && valid_risk_measure && valid_parallel_schema
end

function __build_sddp_simulation_task_definition_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_parallel_schema = __build_parallel_scheme!(d, e)
    return valid_parallel_schema
end
