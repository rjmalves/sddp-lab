# CLASS SDDPEngine -----------------------------------------------------------------------

function SDDPEngine(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_sddp_engine_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_sddp_engine_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_sddp_engine_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_sddp_engine_consistency!(d, e)

    return if valid_consistency
        SDDPEngine(d["policy"], d["simulation"])
    else
        nothing
    end
end

# SDDP METHODS --------------------------------------------------------------------------

# HELPERS -------------------------------------------------------------------------------------

function __build_engine!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_engine_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "engine", e)
end