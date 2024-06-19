# FORM VALIDATORS --------------------------------------------------------------------------

function __validate_keys!(d::Dict, keys::Vector{String}, e::CompositeException)::Bool
    valid = true
    for k in keys
        valid_k = haskey(d, k)
        valid_k || push!(e, ErrorException("Key '$k' not found in dictionary"))
        valid = valid && valid_k
    end

    return valid
end

function __validate_key_lengths!(
    d::Dict, keys::Vector{String}, sizes::Vector{Int}, e::CompositeException
)::Bool
    valid = true
    for (k, s) in zip(keys, sizes)
        valid_l = length(d[k]) == s
        valid_l || push!(e, ErrorException("Key '$k' has length =/= $s"))
        valid = valid && valid_l
    end

    return valid
end

function __validate_key_types!(
    d::Dict, keys::Vector{String}, types::Vector{DataType}, e::CompositeException
)::Bool
    valid = true
    for (k, t) in zip(keys, types)
        aux = __parse_as_type!(d, k, t)
        valid_t = !(typeof(aux) <: Exception)
        valid_t || push!(e, aux)
        valid = valid && valid_t
    end

    return valid
end

# FILE VALIDATORS --------------------------------------------------------------------------

function __validate_file!(filename::String, e::CompositeException)::Bool
    valid = isfile(filename)
    valid || push!(e, ErrorException("$filename not found!"))
    return valid
end

# HELPERS ----------------------------------------------------------------------------------

function __parse_as_type!(d::Dict, k::String, t::DataType)
    if typeof(d[k]) == t
        return nothing
    else
        try
            __try_conversion!(d, k, t)
            return nothing
        catch
            v = d[k]
            err = ErrorException("Value '$v' can't be converted to $t")
            return err
        end
    end
end

function __try_conversion!(d::Dict, k::String, t::DataType)
    return d[k] = convert(t, d[k])
end

function __try_conversion!(d::Dict, k::String, t::Type{String})
    return d[k] = string(d[k])
end

function __try_conversion!(d::Dict, k::String, t::Type{Matrix{T}} where {T})
    aux = stack(d[k])
    return d[k] = convert(t, aux)
end

function __valid_name_regex_match(name::String)
    regex_match = match(r"^[\sa-zA-Z0-9_-]*$", name)
    if regex_match !== nothing
        return regex_match.match == name
    end
    return false
end
