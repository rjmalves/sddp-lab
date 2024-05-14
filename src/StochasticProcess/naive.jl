using Distributions
using LinearAlgebra

import Base: length

# CLASS UnitaryNaive -----------------------------------------------------------------------

struct UnitaryNaive
    id::Integer
    distributions::Dict{Integer, UnivariateDistribution}
end

function UnitaryNaive(d::Dict{String, Any})

    # __validate_dict_unitary_naive

    distributions = Dict{Integer, UnivariateDistribution}()

    for (i, i_dist) in enumerate(d["distributions"])

        name = i_dist["name"]
        seas = Int(i_dist["season"]) # this Int() call should be moved to __validate above
        params = real(i_dist["parameters"]) # this real() call should be moved to __validate above

        i_dist = __instantiate_distribution(name, params)
        i_dist = Dict{Integer, UnivariateDistribution}(seas => i_dist)

        merge!(distributions, i_dist)

    end

    UnitaryNaive(d["id"], distributions)
end

# CLASS Naive ------------------------------------------------------------------------------

struct Naive <: AbstractStochasticProcess

    # each entry corresponds to an element in the system, with key equal to that
    # elements 'id'
    models::Dict{Integer, UnitaryNaive}

    # similar to 'models', but the Int key now corresponds to the season
    R_matrices::Dict{Integer, Matrix{Real}}

end

function Naive(d::Dict{String, Any})
    
    # __validate_dict_naive
    #   __validate_dict_models
    #   __validate_dict_matrices

    models = __build_marginal_models(d)
    matrices = __build_R_matrices(d)

    Naive(models, matrices)

end

function __build_marginal_models(d::Dict{String, Any})

    unitaries = map(ud -> UnitaryNaive(ud), d["marginal_models"])
    ids = map(x -> x.id, unitaries)

    unitaries = Dict{Integer, UnitaryNaive}(zip(ids, unitaries))

    return unitaries
end

function __build_R_matrices(d::Dict{String, Any})

    matrices = map(d["correlation_matrices"]) do mat
        mat = stack(mat["matrix"], dims = 1)
        mat = real(mat) # this real() call should be moved to __validate above
    end

    seasons = map(x -> x["season"], d["correlation_matrices"])
    matrices = Dict{Integer, Matrix{Real}}(zip(seasons, matrices))

    return matrices
end

# METHODS ----------------------------------------------------------------------------------

function __get_ids(s::Naive)
    map(x -> x.id, values(s.models))
end

function length(s::Naive)
    length(__get_ids(s))
end

# HELPERS ----------------------------------------------------------------------------------

"""
    __instantiate_dist(name::String, params::Vector{Real})

Return instance of a distribution from Distributions.jl of type `name` and parameters `params`
"""
function __instantiate_distribution(name::String, params::Vector{T} where T <: Real) 
    d = getfield(Distributions, Symbol(name))(params...)
    return d
end
