# CLASS ExplicitHorizon -----------------------------------------------------------------------

struct ExplicitHorizon <: Horizon
    stages::Vector{Stage}
end

function ExplicitHorizon(d::Dict{String,Any}, e::CompositeException)
    valid_stages = __build_stages!(d, e)
    valid_internals = valid_stages

    valid_keys_types = valid_internals && __validate_explict_horizon_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_explict_horizon_content!(d, e)
    valid_consistency = valid_content && __validate_explict_horizon_consistency!(d, e)
    valid = valid_keys_types && valid_content && valid_consistency

    return valid ? ExplicitHorizon(d["stages"]) : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_horizon!(d::Dict{String,Any}, e::CompositeException)::Bool
    horizon_d = d["horizon"]
    valid_keys = __validate_keys!(horizon_d, ["kind", "params"], e)
    valid_types = __validate_key_types!(
        horizon_d, ["kind", "params"], [String, Dict{String,Any}], e
    )
    valid = valid_keys && valid_types
    if !valid
        return false
    end

    kind = horizon_d["kind"]
    params = horizon_d["params"]

    horizon_obj = nothing
    try
        kind_type = getfield(@__MODULE__, Symbol(kind))
        horizon_obj = kind_type(params, e)
    catch
        push!(e, AssertionError("Horizon kind ($kind) not recognized"))
    end
    d["horizon"] = horizon_obj
    return horizon_obj !== nothing
end