# CLASS Expectation -----------------------------------------------------------------------

struct Expectation <: RiskMeasure end

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
