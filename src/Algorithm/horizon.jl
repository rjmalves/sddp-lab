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

    return valid_consistency ? ExplicitHorizon(d["stages"]) : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_horizon!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_horizon_key = __validate_keys!(d, ["horizon"], e)
    valid_horizon_type =
        valid_horizon_key && __validate_key_types!(d, ["horizon"], [Dict{String,Any}], e)
    if !valid_horizon_type
        return false
    end

    horizon_d = d["horizon"]
    keys = ["kind", "params"]
    keys_types = [String, Dict{String,Any}]
    valid_keys = __validate_keys!(horizon_d, keys, e)
    valid_types = valid_keys && __validate_key_types!(horizon_d, keys, keys_types, e)
    if !valid_types
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