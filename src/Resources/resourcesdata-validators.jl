# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

ENVIRONMENT_KEYS = ["solver"]
ENVIRONMENT_KEY_TYPES = [T where {T<:Solver}]
ENVIRONMENT_KEY_TYPES_BEFORE_BUILD = [Dict{String,Any}]

function __validate_resources_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ENVIRONMENT_KEYS
    keys_types = ENVIRONMENT_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_resources_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ENVIRONMENT_KEYS
    keys_types = ENVIRONMENT_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_resources_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_resources_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_resources_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_solver = __build_solver!(d, e)
    return valid_solver
end

function __cast_resources_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_resources_keys_types_before_build!(d, e)
    valid_solver = valid_key_types && __cast_solver_internals_from_files!(d, e)
    return valid_solver
end