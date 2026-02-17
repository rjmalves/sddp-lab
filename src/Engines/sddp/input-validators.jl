# SCHEMAS ----------------------------------------------------------------------------------

const ITERATION_LIMIT_SCHEMA = [
    FieldRule("num_iterations", Integer; constraints = [positive()]),
]

const TIME_LIMIT_SCHEMA = [
    FieldRule("time_seconds", Integer; constraints = [positive()]),
]

const LOWER_BOUND_STABILITY_SCHEMA = [
    FieldRule("threshold", Real; constraints = [in_range_exclusive(0.0, 1.0)]),
    FieldRule("num_iterations", Integer; constraints = [positive()]),
]

const CONVERGENCE_SCHEMA = [
    FieldRule("min_iterations", Integer; constraints = [positive()]),
    FieldRule("max_iterations", Integer; constraints = [positive()]),
]

const AVAR_SCHEMA = [
    FieldRule("alpha", Real; constraints = [in_range(0.0, 1.0)]),
]

const CVAR_SCHEMA = [
    FieldRule("alpha", Real; constraints = [in_range(0.0, 1.0)]),
    FieldRule("lambda", Real; constraints = [in_range(0.0, 1.0)]),
]

const SDDP_SIMULATION_TASK_DEFINITION_SCHEMA = [
    FieldRule("num_simulated_series", Integer; constraints = [positive()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_stopping_criteria_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["stopping_criteria"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["stopping_criteria"], [Dict{String,Any}], e)
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

function __validate_risk_measure_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["risk_measure"], e)
    valid_types =
        valid_keys && __validate_key_types!(d, ["risk_measure"], [Dict{String,Any}], e)
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

function __validate_convergence_min_max!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    min_iterations = d["min_iterations"]
    max_iterations = d["max_iterations"]
    valid = max_iterations >= min_iterations
    valid || push!(
        e,
        AssertionError(
            "Convergence - max_iterations ($max_iterations) must be >= min_iterations ($min_iterations)",
        ),
    )
    return valid
end

# HELPERS ----------------------------------------------------------------------------------

function __build_convergence_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __build_stopping_criteria!(d, e)
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
    return __build_parallel_scheme!(d, e)
end
