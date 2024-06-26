# KEYS / TYPES VALIDATORS -------------------------------------------------------------------
function __validate_environment_keys_types_pre_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["solver"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys ? __validate_key_types!(d, keys, keys_types, e) : false
    return valid_keys && valid_types
end

function __validate_environment_keys_types_pos_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["solver"]
    keys_types = [T where {T<:Solver}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys ? __validate_key_types!(d, keys, keys_types, e) : false
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------
# TODO
function __validate_solver_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end