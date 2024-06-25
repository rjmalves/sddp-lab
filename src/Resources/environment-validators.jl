# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_environment_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["solver"]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys ? __validate_key_types!(d, keys, [Solver], e) : false
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------
# TODO
function __validate_solver_content!(
    d::Dict{String,Any}, e::CompositeException
)::Vector{Dict{String,Any}}
    return true
end