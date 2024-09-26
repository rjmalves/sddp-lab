# CLASS ExplicitHorizon -----------------------------------------------------------------------

function ExplicitHorizon(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_explicit_horizon_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_explicit_horizon_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_explicit_horizon_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_explicit_horizon_consistency!(d, e)

    return valid_consistency ? ExplicitHorizon(d["stages"]) : nothing
end

function length(h::ExplicitHorizon)::Integer
    return length(h.stages)
end

# HELPERS -------------------------------------------------------------------------------------

function __build_horizon!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_horizon_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "horizon", e)
end

function __cast_horizon_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    horizon_d = d["horizon"]
    should_cast_from_file = __validate_file_key!(horizon_d, e)

    valid = !should_cast_from_file
    if should_cast_from_file
        valid = __validate_cast_from_csv_file!(horizon_d, "stages", e)
    end

    return valid
end
