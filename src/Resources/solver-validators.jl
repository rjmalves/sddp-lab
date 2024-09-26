# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_solver_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["solver"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["solver"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_clp_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_glpk_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_highs_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_clp_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_glpk_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_highs_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_clp_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_glpk_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_highs_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPERS -----------------------------------------------------------------------------------

function __build_clp_internals_from_dicts!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __build_glpk_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
function __build_highs_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
