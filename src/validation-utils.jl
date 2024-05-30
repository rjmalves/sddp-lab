# FORM VALIDATORS --------------------------------------------------------------------------

function __validate_keys!(d::Dict, keys::Vector{String}, e::CompositeException)
    for k in keys
        haskey(d, k) || push!(e, ErrorException("Key '$k' not found in dictionary"))
    end

    return nothing
end

function __validate_key_length(
    d::Dict, keys::Vector{String}, sizes::Vector{Int}, e::CompositeException
) end

function __validate_key_types!(
    d::Dict, keys::Vector{String}, types::Vector{DataType}, e::CompositeException
)
    for (k, t) in zip(keys, types)
        aux = __parse_as_type!(d, k, t)
        typeof(aux) <: Exception ? push!(e, aux) : nothing
    end

    return nothing
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

function throw_composite_exception_if_any(e::CompositeException)
    if length(e) > 0
        throw(e)
    end
end