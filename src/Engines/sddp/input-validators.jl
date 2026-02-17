const DIAGNOSTICS_SCHEMA = [
    FieldRule("run_numerical_report", Bool),
    FieldRule("warn_threshold", Real; constraints = [positive()]),
    FieldRule("halt_threshold", Real; constraints = [positive()]),
]

const SOLVER_CONFIG_SCHEMA = [
    FieldRule("name", String; constraints = [non_empty()]),
]

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

const STATISTICAL_SCHEMA = [
    FieldRule("num_replications", Integer; constraints = [positive()]),
    FieldRule("iteration_period", Integer; constraints = [positive()]),
    FieldRule("z_score", Real; constraints = [positive()]),
]

const SIMULATION_STOPPING_SCHEMA = [
    FieldRule("replications", Integer; constraints = [positive()]),
    FieldRule("period", Integer; constraints = [positive()]),
]

const FIRST_STAGE_STOPPING_SCHEMA = [
    FieldRule("atol", Real; constraints = [positive()]),
    FieldRule("iterations", Integer; constraints = [positive()]),
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

const ENTROPIC_SCHEMA = [
    FieldRule("theta", Real; constraints = [positive()]),
]

const WASSERSTEIN_RM_SCHEMA = [
    FieldRule("alpha", Real; constraints = [in_range_exclusive(0.0, 1.0)]),
]

const MODIFIED_CHI_SQUARED_SCHEMA = [
    FieldRule("radius", Real; constraints = [positive()]),
    FieldRule("minimum_std", Real; constraints = [in_range_exclusive(0.0, 1.0)]),
]

const SDDP_SIMULATION_TASK_DEFINITION_SCHEMA = [
    FieldRule("num_simulated_series", Integer; constraints = [positive()]),
]

const INSAMPLE_MC_SCHEMA = [
    FieldRule("max_depth", Integer; constraints = [positive()]),
    FieldRule("terminate_on_dummy_leaf", Bool),
]

const PSR_SAMPLING_SCHEMA = [
    FieldRule("num_samples", Integer; constraints = [positive()]),
]

const REVISITING_FORWARD_PASS_SCHEMA = [
    FieldRule("period", Integer; constraints = [positive()]),
]

const REGULARIZED_FORWARD_PASS_SCHEMA = [
    FieldRule("rho", Real; constraints = [positive()]),
]

function __validate_diagnostics_halt_ge_warn!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    halt = d["halt_threshold"]
    warn = d["warn_threshold"]
    valid = halt >= warn
    valid || push!(
        e,
        AssertionError(
            "DiagnosticsConfig - halt_threshold ($halt) must be >= warn_threshold ($warn)",
        ),
    )
    return valid
end

function __validate_stopping_criteria_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["stopping_criteria"], e)
    if !valid_keys
        return false
    end

    sc = d["stopping_criteria"]
    if sc isa Dict
        valid_types = __validate_key_types!(d, ["stopping_criteria"], [Dict{String,Any}], e)
        return valid_types
    elseif sc isa Vector
        for (i, item) in enumerate(sc)
            if !(item isa Dict)
                push!(
                    e,
                    ErrorException(
                        "stopping_criteria[$i] must be a Dict, got $(typeof(item))",
                    ),
                )
                return false
            end
        end
        if isempty(sc)
            push!(e, AssertionError("stopping_criteria must be non-empty"))
            return false
        end
        d["stopping_criteria"] = convert(Vector{Dict{String,Any}}, sc)
        return true
    else
        push!(
            e,
            ErrorException(
                "Key 'stopping_criteria' must be a Dict or a Vector, got $(typeof(sc))",
            ),
        )
        return false
    end
end

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
    base_keys = ["min_iterations", "max_iterations"]
    base_types = [Integer, Integer]
    valid_keys = __validate_keys!(d, base_keys, e)
    valid_types = valid_keys && __validate_key_types!(d, base_keys, base_types, e)

    valid_sc_key = __validate_keys!(d, ["stopping_criteria"], e)
    if valid_sc_key
        sc = d["stopping_criteria"]
        if !(sc isa Vector{StoppingCriteria})
            push!(
                e,
                ErrorException(
                    "Key 'stopping_criteria' must be a Vector{StoppingCriteria}, got $(typeof(sc))",
                ),
            )
            valid_types = false
        end
    else
        valid_types = false
    end

    return valid_types
end

function __validate_convergence_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    base_keys = ["min_iterations", "max_iterations"]
    base_types = [Integer, Integer]
    valid_keys = __validate_keys!(d, base_keys, e)
    valid_types = valid_keys && __validate_key_types!(d, base_keys, base_types, e)

    valid_sc_key = __validate_keys!(d, ["stopping_criteria"], e)
    if valid_sc_key
        sc = d["stopping_criteria"]
        if !(sc isa Dict || sc isa Vector)
            push!(
                e,
                ErrorException(
                    "Key 'stopping_criteria' must be a Dict or Vector, got $(typeof(sc))",
                ),
            )
            valid_types = false
        end
    else
        valid_types = false
    end

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
    if valid_types && haskey(d, "sampling_scheme")
        valid_types = __validate_key_types!(
            d, ["sampling_scheme"], [Dict{String,Any}], e
        )
    end
    if valid_types && haskey(d, "duality_handler")
        valid_types = __validate_key_types!(
            d, ["duality_handler"], [Dict{String,Any}], e
        )
    end
    if valid_types && haskey(d, "forward_pass")
        valid_types = __validate_key_types!(
            d, ["forward_pass"], [Dict{String,Any}], e
        )
    end
    if valid_types && haskey(d, "cut_type")
        valid_types = __validate_key_types!(
            d, ["cut_type"], [Dict{String,Any}], e
        )
    end
    if valid_types && haskey(d, "scaling")
        valid_types = __validate_key_types!(
            d, ["scaling"], [Dict{String,Any}], e
        )
    end
    return valid_types
end

function __validate_sddp_policy_task_definition_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(
        d,
        [
            "convergence",
            "risk_measure",
            "parallel_scheme",
            "sampling_scheme",
            "duality_handler",
            "forward_pass",
            "cut_type",
            "scaling",
        ],
        e,
    )
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            [
                "convergence",
                "risk_measure",
                "parallel_scheme",
                "sampling_scheme",
                "duality_handler",
                "forward_pass",
                "cut_type",
                "scaling",
            ],
            [
                Convergence,
                T where {T<:RiskMeasure},
                T where {T<:ParallelScheme},
                T where {T<:SamplingScheme},
                T where {T<:DualityHandler},
                T where {T<:ForwardPassStrategy},
                T where {T<:CutType},
                T where {T<:ScalingMode},
            ],
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
    if valid_types && haskey(d, "sampling_scheme")
        valid_types = __validate_key_types!(
            d, ["sampling_scheme"], [Dict{String,Any}], e
        )
    end
    return valid_types
end

function __validate_sddp_simulation_task_definition_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(
        d, ["num_simulated_series", "parallel_scheme", "sampling_scheme"], e
    )
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["num_simulated_series", "parallel_scheme", "sampling_scheme"],
            [Integer, T where {T<:ParallelScheme}, T where {T<:SamplingScheme}],
            e,
        )
    return valid_types
end

function __validate_sampling_scheme_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["sampling_scheme"], e)
    valid_types =
        valid_keys &&
        __validate_key_types!(d, ["sampling_scheme"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_duality_handler_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["duality_handler"], e)
    valid_types =
        valid_keys &&
        __validate_key_types!(d, ["duality_handler"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_forward_pass_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["forward_pass"], e)
    valid_types =
        valid_keys &&
        __validate_key_types!(d, ["forward_pass"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_cut_type_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["cut_type"], e)
    valid_types =
        valid_keys &&
        __validate_key_types!(d, ["cut_type"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_scaling_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["scaling"], e)
    valid_types =
        valid_keys &&
        __validate_key_types!(d, ["scaling"], [Dict{String,Any}], e)
    return valid_types
end

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

function __validate_convex_combination_measures_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["measures"], e)
    if !valid_keys
        return false
    end
    measures = d["measures"]
    if !(measures isa Vector)
        push!(e, ErrorException("Key 'measures' must be a Vector"))
        return false
    end
    if isempty(measures)
        push!(e, AssertionError("ConvexCombination measures must be non-empty"))
        return false
    end
    return true
end

function __validate_convex_combination_weights!(
    measures::Vector{Tuple{Real,RiskMeasure}}, e::CompositeException
)::Bool
    weight_sum = sum(first(m) for m in measures)
    valid = abs(weight_sum - 1.0) <= 1e-6
    valid || push!(
        e,
        AssertionError(
            "ConvexCombination weights sum to $weight_sum, expected 1.0",
        ),
    )
    return valid
end

function __validate_stopping_chain_rules_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["rules"], e)
    if !valid_keys
        return false
    end
    rules = d["rules"]
    if !(rules isa Vector)
        push!(e, ErrorException("Key 'rules' must be a Vector"))
        return false
    end
    if isempty(rules)
        push!(e, AssertionError("StoppingChain must have at least one rule"))
        return false
    end
    return true
end

function __validate_bandit_duality_handlers_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["handlers"], e)
    if !valid_keys
        return false
    end
    handlers = d["handlers"]
    if !(handlers isa Vector)
        push!(e, ErrorException("Key 'handlers' must be a Vector"))
        return false
    end
    if isempty(handlers)
        push!(
            e,
            AssertionError("BanditDualityHandler must have at least 2 handlers"),
        )
        return false
    end
    return true
end

function __validate_bandit_duality_handler_count!(
    handlers::Vector{DualityHandler}, e::CompositeException
)::Bool
    valid = length(handlers) >= 2
    valid || push!(
        e,
        AssertionError("BanditDualityHandler must have at least 2 handlers"),
    )
    return valid
end

function __build_sddp_policy_task_definition_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stopping_criteria = __build_convergence!(d, e)
    valid_risk_measure = __build_risk_measure!(d, e)
    valid_parallel_schema = __build_parallel_scheme!(d, e)
    valid_sampling_scheme = __build_sampling_scheme!(d, e)
    valid_duality_handler = __build_duality_handler!(d, e)
    valid_forward_pass = __build_forward_pass!(d, e)
    valid_cut_type = __build_cut_type!(d, e)
    valid_scaling = __build_scaling!(d, e)
    return valid_stopping_criteria &&
           valid_risk_measure &&
           valid_parallel_schema &&
           valid_sampling_scheme &&
           valid_duality_handler &&
           valid_forward_pass &&
           valid_cut_type &&
           valid_scaling
end

function __build_sddp_simulation_task_definition_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_parallel = __build_parallel_scheme!(d, e)
    valid_sampling = __build_sampling_scheme!(d, e)
    return valid_parallel && valid_sampling
end
