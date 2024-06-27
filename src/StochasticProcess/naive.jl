# CLASS UnitaryNaive -----------------------------------------------------------------------

struct UnitaryNaive
    id::Integer
    distributions::Dict{Integer,UnivariateDistribution}
end

function UnitaryNaive(d::Dict{String,Any})

    # __validate_dict_unitary_naive

    distributions = Dict{Integer,UnivariateDistribution}()

    for (i, i_dist) in enumerate(d["distributions"])
        name = i_dist["kind"]
        seas = Int(i_dist["season"]) # this Int() call should be moved to __validate above
        params = real(i_dist["parameters"]) # this real() call should be moved to __validate above

        i_dist = __instantiate_distribution(name, params)
        i_dist = Dict{Integer,UnivariateDistribution}(seas => i_dist)

        merge!(distributions, i_dist)
    end

    return UnitaryNaive(d["id"], distributions)
end

# CLASS Naive ------------------------------------------------------------------------------

struct Naive <: AbstractStochasticProcess

    # each entry corresponds to an element in the system, with key equal to that
    # elements 'id'
    models::Dict{Integer,UnitaryNaive}

    # similar to 'models', but the Int key now corresponds to the season
    copulas::Dict{Integer,Copula}
end

function Naive(d::Dict{String,Any})

    # __validate_dict_naive
    #   __validate_dict_models
    #   __validate_dict_matrices

    models = __build_marginal_models(d)
    matrices = __build_copulas(d)

    return Naive(models, matrices)
end

function Naive(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    return d !== nothing ? Naive(d) : nothing
end

function __build_marginal_models(d::Dict{String,Any})
    unitaries = map(ud -> UnitaryNaive(ud), d["marginal_models"])
    ids = map(x -> x.id, unitaries)

    unitaries = Dict{Integer,UnitaryNaive}(zip(ids, unitaries))

    return unitaries
end

function __build_copulas(d::Dict{String,Any})
    copulas = Dict{Integer,Copula}()

    for (i, i_copula) in enumerate(d["copulas"])
        name = i_copula["name"]
        seas = Int(i_copula["season"]) # this Int() call should be moved to __validate
        params = real(stack(i_copula["parameters"])) # this block should be moved to a __validate

        i_copula = __instantiate_copula(name, params)
        i_copula = Dict{Integer,Copula}(seas => i_copula)

        merge!(copulas, i_copula)
    end

    return copulas
end

# GENERAL METHODS --------------------------------------------------------------------------

function __get_ids(s::Naive)
    return map(x -> x.id, values(s.models))
end

function length(s::Naive)
    return length(__get_ids(s))
end

function size(s::Naive)
    first_id = __get_ids(s)[1]
    first_us = s.models[first_id]

    return (length(__get_ids(s)), length(first_us.distributions))
end

# SDDP METHODS -----------------------------------------------------------------------------

function __generate_saa(
    rng::AbstractRNG, s::Naive, initial_season::Integer, N::Integer, B::Integer
)
    size_s = size(s)

    out = [zeros(Float64, (size_s[1], B)) for n in range(1, N)]

    for n in range(1, N)
        m = (n + initial_season - 1)

        # this + 1e-5 is a trick to allow cycling over the seasons -- might be worth some
        # optimization in the future
        season = m - size_s[2] * Int(div(m, size_s[2] + 1e-5))
        D = __build_mvdist(s, season)
        out[n] .+= rand(rng, D, B)
    end

    return out
end

# function generate_saa(s::Naive, initial_season::Integer, N::Integer, B::Integer)
#     return __generate_saa(Random.default_rng(), s, initial_season, N, B)
# end

function add_inflow_uncertainty!(m::JuMP.Model, s::Naive)
    n_hydro = length(s)

    @variable(m, ω_inflow[1:n_hydro])
    @constraint(m, inflow_model, m[:ena] .== ω_inflow)

    return m
end

# HELPERS ----------------------------------------------------------------------------------

function __build_mvdist(s::Naive, season::Int)
    ids = __get_ids(s)

    marginals = (s.models[id].distributions[season] for id in ids)
    copula = s.copulas[season]

    D = SklarDist(copula, marginals)

    return D
end

"""
    __instantiate_dist(name::String, params::Vector{Real})

Return instance of a distribution from Distributions.jl of type `name` and parameters `params`
"""
function __instantiate_distribution(name::String, params::Vector{T} where {T<:Real})
    d = getfield(Distributions, Symbol(name))(params...)
    return d
end

"""
    __instantiate_copula(name::String, params::Vector{Real})

Return instance of a copula from Copulas.jl of type `name` and parameters `params`
"""
function __instantiate_copula(
    name::String, params::Union{Vector{T},Matrix{Float64}} where {T<:Real}
)
    d = getfield(Copulas, Symbol(name))(params...)
    return d
end
