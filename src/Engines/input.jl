# CLASS SDDPEngine -----------------------------------------------------------------------

function SDDPEngine(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_engine_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_sddp_engine_keys_types!(d, e)

    return if valid_keys_types
        SDDPEngine(d["policy"], d["simulation"])
    else
        nothing
    end
end

# HELPERS -------------------------------------------------------------------------------------

function __build_engine!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_engine_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "engine", e)
end