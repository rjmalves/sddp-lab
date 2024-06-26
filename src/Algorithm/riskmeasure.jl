# CLASS Expectation -----------------------------------------------------------------------

struct Expectation <: RiskMeasure end

function Expectation(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_expectation_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_expectation_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? Expectation() : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_risk_measure!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_risk_measure_key = __validate_keys!(d, ["risk_measure"], e)
    valid_risk_measure_type =
        valid_risk_measure_key &&
        __validate_key_types!(d, ["risk_measure"], [Dict{String,Any}], e)
    if !valid_risk_measure_type
        return false
    end

    risk_measure_d = d["risk_measure"]
    keys = ["kind", "params"]
    keys_types = [String, Dict{String,Any}]
    valid_keys = __validate_keys!(risk_measure_d, keys, e)
    valid_types = valid_keys && __validate_key_types!(risk_measure_d, keys, keys_types, e)
    if !valid_types
        return valid_types
    end

    kind = risk_measure_d["kind"]
    params = risk_measure_d["params"]

    risk_measure_obj = nothing
    try
        kind_type = getfield(@__MODULE__, Symbol(kind))
        risk_measure_obj = kind_type(params, e)
    catch
        push!(e, AssertionError("Risk measure kind ($kind) not recognized"))
    end
    d["risk_measure"] = risk_measure_obj

    return risk_measure_obj !== nothing
end