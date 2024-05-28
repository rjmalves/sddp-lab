# FORM VALIDATORS --------------------------------------------------------------------------

function __validate_keys(d::Dict, keys::Vector{String}, e::CompositeException)
end

function __validate_key_length(d::Dict, keys::Vector{String}, sizes::Vector{Int},
    e::CompositeException)
end

function __validate_key_type!(d::Dict, keys::Vector{String}, types::Vector{DataType},
    e::CompositeException)

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
            err = ErrorException("Value can't be converted to $t")
            return err
        end
    end
end

function __try_conversion!(d::Dict, k::String, t::DataType)
    d[k] = convert(t, d[k])
end

function __try_conversion!(d::Dict, k::String, t::Type{String})
    d[k] = string(d[k])
end

function __try_conversion!(d::Dict, k::String, t::Type{Matrix{T}} where T)
    aux = stack(d[k])
    d[k] = convert(t, aux)
end