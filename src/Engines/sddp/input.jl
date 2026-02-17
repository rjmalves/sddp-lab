# CLASS IterationLimit -----------------------------------------------------------------------

function IterationLimit(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, ITERATION_LIMIT_SCHEMA, e)
    return valid ? IterationLimit(d["num_iterations"]) : nothing
end

# CLASS TimeLimit -----------------------------------------------------------------------

function TimeLimit(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, TIME_LIMIT_SCHEMA, e)
    return valid ? TimeLimit(d["time_seconds"]) : nothing
end

# CLASS LowerBoundStability -----------------------------------------------------------------------

function LowerBoundStability(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, LOWER_BOUND_STABILITY_SCHEMA, e)
    return valid ? LowerBoundStability(d["threshold"], d["num_iterations"]) : nothing
end

# CLASS Convergence -----------------------------------------------------------------------

function Convergence(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_convergence_internals_from_dicts!(d, e)
    valid_schema = valid_internals && validate_schema!(d, CONVERGENCE_SCHEMA, e)
    valid_keys_types = valid_schema && __validate_convergence_keys_types!(d, e)
    valid_cross = valid_keys_types && __validate_convergence_min_max!(d, e)

    return if valid_cross
        Convergence(d["min_iterations"], d["max_iterations"], d["stopping_criteria"])
    else
        nothing
    end
end

# CLASS Serial -----------------------------------------------------------------------

function Serial(::Dict{String,Any}, ::CompositeException)
    return Serial()
end

# CLASS Asynchronous -----------------------------------------------------------------------

function Asynchronous(::Dict{String,Any}, ::CompositeException)
    return Asynchronous()
end

# CLASS Expectation -----------------------------------------------------------------------

function Expectation(::Dict{String,Any}, ::CompositeException)
    return Expectation()
end

# CLASS WorstCase -----------------------------------------------------------------------

function WorstCase(::Dict{String,Any}, ::CompositeException)
    return WorstCase()
end

# CLASS AVaR -----------------------------------------------------------------------

function AVaR(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, AVAR_SCHEMA, e)
    return valid ? AVaR(d["alpha"]) : nothing
end

# CLASS CVaR -----------------------------------------------------------------------

function CVaR(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, CVAR_SCHEMA, e)
    return valid ? CVaR(d["alpha"], d["lambda"]) : nothing
end

# CLASS SDDPPolicyTaskDefinition -----------------------------------------------------------------------

function SDDPPolicyTaskDefinition(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_policy_task_definition_internals_from_dicts!(d, e)
    valid_keys_types =
        valid_internals && __validate_sddp_policy_task_definition_keys_types!(d, e)

    return if valid_keys_types
        SDDPPolicyTaskDefinition(d["convergence"], d["risk_measure"], d["parallel_scheme"])
    else
        nothing
    end
end

# CLASS SDDPSimulationTaskDefinition -----------------------------------------------------------------------

function SDDPSimulationTaskDefinition(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_simulation_task_definition_internals_from_dicts!(d, e)
    valid_schema =
        valid_internals && validate_schema!(d, SDDP_SIMULATION_TASK_DEFINITION_SCHEMA, e)
    valid_keys_types =
        valid_schema && __validate_sddp_simulation_task_definition_keys_types!(d, e)

    return if valid_keys_types
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

function __build_parallel_scheme!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_parallel_scheme_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "parallel_scheme", e)
end

function __build_risk_measure!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_risk_measure_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "risk_measure", e)
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
