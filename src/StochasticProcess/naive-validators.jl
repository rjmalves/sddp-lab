# FORM VALIDATORS --------------------------------------------------------------------------

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_distribution_name(name::String)
    as_symbol = Symbol(name)
    try
        getfield(Distributions, as_symbol) <: UnivariateDistribution
    catch
        return AssertionError("$name is not a valid UnivariateDistribution")
    end

    return true
end

function __validate_distribution_params(name::String, params::Vector{T} where T <: Real)
    try
        __instantiate_dist(name, params)
    catch 
        return AssertionError("`$params` not a valid set of parameters for distribution `$name`")
    end

    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------
