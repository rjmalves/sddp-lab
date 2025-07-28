# CLASS IterationLimit -----------------------------------------------------------------------

function IterationLimit(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_iteration_limit_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_iteration_limit_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_iteration_limit_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_iteration_limit_consistency!(d, e)

    return if valid_consistency
        IterationLimit(d["num_iterations"])
    else
        nothing
    end
end

# CLASS TimeLimit -----------------------------------------------------------------------

function TimeLimit(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_time_limit_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_time_limit_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_time_limit_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_time_limit_consistency!(d, e)

    return if valid_consistency
        TimeLimit(d["time_seconds"])
    else
        nothing
    end
end

# CLASS LowerBoundStability -----------------------------------------------------------------------

function LowerBoundStability(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_lower_bound_stability_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_lower_bound_stability_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_lower_bound_stability_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_lower_bound_stability_consistency!(d, e)

    return if valid_consistency
        LowerBoundStability(d["threshold"], d["num_iterations"])
    else
        nothing
    end
end

# CLASS Convergence -----------------------------------------------------------------------

function Convergence(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_convergence_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_convergence_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_convergence_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_convergence_consistency!(d, e)

    return if valid_consistency
        Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"])
    else
        nothing
    end
end

# CLASS Serial -----------------------------------------------------------------------

function Serial(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_serial_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_serial_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_serial_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_serial_consistency!(d, e)

    return valid_consistency ? Serial() : nothing
end

# CLASS Asynchronous -----------------------------------------------------------------------

function Asynchronous(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_asynchronous_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_asynchronous_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_asynchronous_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_asynchronous_consistency!(d, e)

    return valid_consistency ? Asynchronous() : nothing
end

# CLASS Expectation -----------------------------------------------------------------------

function Expectation(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_expectation_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_expectation_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_expectation_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_expectation_consistency!(d, e)

    return valid_consistency ? Expectation() : nothing
end

# CLASS WorstCase -----------------------------------------------------------------------

function WorstCase(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_worstcase_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_worstcase_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_worstcase_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_worstcase_consistency!(d, e)

    return valid_consistency ? WorstCase() : nothing
end

# CLASS AVaR -----------------------------------------------------------------------

function AVaR(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_avar_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_avar_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_avar_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_avar_consistency!(d, e)

    return valid_consistency ? AVaR(d["alpha"]) : nothing
end

# CLASS CVaR -----------------------------------------------------------------------

function CVaR(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_cvar_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_cvar_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_cvar_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_cvar_consistency!(d, e)

    return valid_consistency ? CVaR(d["alpha"], d["lambda"]) : nothing
end

# CLASS SDDPPolicyTaskDefinition -----------------------------------------------------------------------

function SDDPPolicyTaskDefinition(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_policy_definition_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_policy_definition_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_policy_definition_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_policy_definition_consistency!(d, e)

    return if valid_consistency
        SDDPPolicyTaskDefinition(d["convergence"], d["risk_measure"], d["parallel_scheme"])
    else
        nothing
    end
end

# CLASS SDDPSimulationTaskDefinition -----------------------------------------------------------------------

function SDDPSimulationTaskDefinition(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_simulation_definition_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_simulation_definition_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_simulation_definition_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_simulation_definition_consistency!(d, e)

    return if valid_consistency
        SDDPSimulationTaskDefinition(d["num_simulated_series"], d["parallel_scheme"])
    else
        nothing
    end
end

# SDDP METHODS --------------------------------------------------------------------------

function generate_stopping_rule(s::IterationLimit)::SDDP.AbstractStoppingRule
    return SDDP.IterationLimit(s.num_iterations)
end

function generate_stopping_rule(s::TimeLimit)::SDDP.AbstractStoppingRule
    return SDDP.TimeLimit(s.time_seconds)
end

function generate_stopping_rule(s::LowerBoundStability)::SDDP.AbstractStoppingRule
    return SDDP.BoundStalling(s.num_iterations, s.threshold)
end

function generate_parallel_scheme(p::Serial)::SDDP.AbstractParallelScheme
    return SDDP.Serial()
end

function generate_parallel_scheme(p::Asynchronous)::SDDP.AbstractParallelScheme
    return SDDP.Asynchronous()
end

function generate_risk_measure(r::Expectation)::SDDP.AbstractRiskMeasure
    return SDDP.Expectation()
end

function generate_risk_measure(r::WorstCase)::SDDP.AbstractRiskMeasure
    return SDDP.WorstCase()
end

function generate_risk_measure(r::AVaR)::SDDP.AbstractRiskMeasure
    return SDDP.AVaR(r.alpha)
end

function generate_risk_measure(r::CVaR)::SDDP.AbstractRiskMeasure
    return SDDP.EAVaR(; beta = r.alpha, lambda = (1 - r.lambda))
end

# HELPERS -------------------------------------------------------------------------------------

function __build_stopping_criteria!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stopping_criteria_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "stopping_criteria", e)
end

function __cast_stopping_criteria_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_convergence!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_convergence_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    convergence_d = d["convergence"]

    valid_key_types = __validate_convergence_keys_types_before_build!(convergence_d, e)
    if !valid_key_types
        return false
    end

    d["convergence"] = Convergence(convergence_d, e)
    return d["convergence"] !== nothing
end

function __cast_convergence_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_parallel_scheme!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_parallel_scheme_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "parallel_scheme", e)
end

function __cast_parallel_scheme_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_risk_measure!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_risk_measure_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "risk_measure", e)
end

function __cast_risk_measure_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_sddp_policy_task_definition!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_sddp_policy_task_definition_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    policy_d = d["policy"]

    valid_key_types = __validate_sddp_policy_task_definition_keys_types_before_build!(
        policy_d, e
    )
    if !valid_key_types
        return false
    end

    d["policy"] = SDDPPolicyTaskDefinition(policy_d, e)
    return d["policy"] !== nothing
end

function __build_sddp_simulation_task_definition!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_sddp_simulation_task_definition_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    simulation_d = d["simulation"]

    valid_key_types = __validate_sddp_simulation_task_definition_keys_types_before_build!(
        simulation_d, e
    )
    if !valid_key_types
        return false
    end

    d["simulation"] = SDDPSimulationTaskDefinition(simulation_d, e)
    return d["simulation"] !== nothing
end
