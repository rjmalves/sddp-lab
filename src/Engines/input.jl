function SDDPEngine(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_engine_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_sddp_engine_keys_types!(d, e)

    return if valid_keys_types
        SDDPEngine(
            d["policy"],
            d["simulation"],
            d["diagnostics"],
            d["solver"],
            d["inflow_non_negativity"],
            d["validation"],
            d["debug"],
        )
    else
        nothing
    end
end

function __build_engine!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_engine_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "engine", e)
end

function InflowNone(::Dict{String,Any}, ::CompositeException)
    return InflowNone()
end

function InflowPenalty(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, INFLOW_PENALTY_SCHEMA, e)
    return valid ? InflowPenalty(d["penalty_cost"]) : nothing
end

function InflowTruncation(::Dict{String,Any}, ::CompositeException)
    return InflowTruncation()
end

function InflowTruncationWithPenalty(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, INFLOW_PENALTY_SCHEMA, e)
    return valid ? InflowTruncationWithPenalty(d["penalty_cost"]) : nothing
end

function __build_inflow_non_negativity!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "modeling") || !haskey(d["modeling"], "inflow_non_negativity")
        d["inflow_non_negativity"] = InflowNone()
        return true
    end

    modeling = d["modeling"]
    inn_d = modeling["inflow_non_negativity"]
    if !(inn_d isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'inflow_non_negativity' must be a Dict{String,Any}, got $(typeof(inn_d))",
            ),
        )
        return false
    end

    temp = Dict{String,Any}("inflow_non_negativity" => convert(Dict{String,Any}, inn_d))
    result = __kind_factory!(@__MODULE__, temp, "inflow_non_negativity", e)
    if result
        d["inflow_non_negativity"] = temp["inflow_non_negativity"]
    end
    return result
end

function OutOfSampleValidation(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_parallel_scheme!(d, e)
    valid_schema = valid_internals && validate_schema!(d, VALIDATION_SCHEMA, e)
    valid_keys_types = valid_schema && __validate_validation_keys_types!(d, e)

    return if valid_keys_types
        OutOfSampleValidation(
            d["num_simulations"], d["seed"], d["branchings"], d["parallel_scheme"]
        )
    else
        nothing
    end
end

function __build_validation!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "validation")
        d["validation"] = nothing
        return true
    end

    val = d["validation"]
    if !(val isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'validation' must be a Dict{String,Any}, got $(typeof(val))"
            ),
        )
        return false
    end

    val_d = convert(Dict{String,Any}, val)
    result = OutOfSampleValidation(val_d, e)
    if result === nothing
        return false
    end

    d["validation"] = result
    return true
end
