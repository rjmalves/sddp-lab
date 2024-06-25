# CLASS LowerBoundStability -----------------------------------------------------------------------

struct LowerBoundStability <: StoppingCriteria
    threshold::Real
    num_iterations::Integer
end

function LowerBoundStability(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_lower_bound_stability_keys_types!(d, e)
    valid_content =
        valid_keys_types ? __validate_lower_bound_stability_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? LowerBoundStability(d["threshold"], d["num_iterations"]) : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_stopping_criteria!(d::Dict{String,Any}, e::CompositeException)::Bool
    stopping_criteria_d = d["stopping_criteria"]
    valid_keys = __validate_keys!(stopping_criteria_d, ["kind", "params"], e)
    valid_types = __validate_key_types!(
        stopping_criteria_d, ["kind", "params"], [String, Dict{String,Any}], e
    )
    valid = valid_keys && valid_types
    if !valid
        return false
    end

    kind = stopping_criteria_d["kind"]
    params = stopping_criteria_d["params"]

    stopping_criteria_obj = nothing
    try
        kind_type = getfield(@__MODULE__, Symbol(kind))
        stopping_criteria_obj = kind_type(params, e)
    catch
        push!(e, AssertionError("Stopping criteria kind ($kind) not recognized"))
    end

    d["stopping_criteria"] = stopping_criteria_obj

    return stopping_criteria_obj !== nothing
end