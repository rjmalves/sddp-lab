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

# SDDP METHODS --------------------------------------------------------------------------

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
