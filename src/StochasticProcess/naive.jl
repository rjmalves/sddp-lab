struct UnitaryNaive
    id::Integer
    distributions::Dict{Integer,UnivariateDistribution}
end

function UnitaryNaive(d::Dict{String,Any})::UnitaryNaive
    distributions = Dict(enumerate([__build_unitarynaive_seasonal_model(id) for id in d["distributions"]]))
    return UnitaryNaive(d["id"], distributions)
end

function __build_unitarynaive_seasonal_model(d::Dict{String,Any})::Distributions.UnivariateDistribution
    return __instantiate_distribution(d["kind"], Tuple(real(d["parameters"])))
end

struct Naive <: AbstractStochasticProcess
    models::Vector{UnitaryNaive}
    copulas::Dict{Integer,Copula}
end

function Naive(d::Dict{String,Any}, e::CompositeException)::Naive
    return Naive(__build_unitarynaives(d), __build_copulas(d))
end

function __build_unitarynaives(d::Dict{String,Any})::Vector{UnitaryNaive}
    return map(UnitaryNaive, d["marginal_models"])
end

function __build_copulas(d::Dict{String,Any})::Dict{Integer,Copula}
    return Dict(enumerate([__build_copula(id) for id in d["copulas"]]))
end

function __build_copula(d::Dict{String,Any})::Copula
    return __instantiate_copula(d["kind"], tuple(real(stack(d["parameters"]))))
end

function __get_ids(s::Naive)::Vector{Integer}
    return map(x -> x.id, values(s.models))
end

function length(s::Naive)::Integer
    return length(__get_ids(s))
end

function size(s::Naive)::Tuple{Integer,Vararg{Integer}}
    first_us = s.models[__get_ids(s)[1]]
    return (length(__get_ids(s)), length(first_us.distributions))
end

function size(s::Naive, i::Int)
    return size(s)[i]
end

function __generate_saa(
    rng::AbstractRNG, s::Naive, initial_season::Integer, N::Integer, B::Integer
)::Vector{Vector{Vector{Float64}}}
    size_s = size(s)
    out = [[zeros(size_s[1]) for b in range(1, B)] for n in range(1, N)]
    # (n_vars x 1) buffer avoids one Matrix allocation per sample vs rand(rng, D, 1)
    buffer = zeros(size_s[1], 1)

    for n in range(1, N)
        m = (n + initial_season - 1)
        # + 1e-5 is a trick to allow cycling over the seasons
        season = m - size_s[2] * Int(div(m, size_s[2] + 1e-5))
        D = __build_mvdist(s, season)
        for b in range(1, B)
            rand!(rng, D, buffer)
            # Use .= rather than .+= since out[n][b] is initialised to zeros
            out[n][b] .= @view buffer[:, 1]
        end
    end

    return out
end

function __build_mvdist(s::Naive, season::Int)::Copulas.SklarDist
    num_models = size(s)[1]
    marginals = (s.models[i].distributions[season] for i in range(1, num_models))
    return SklarDist(s.copulas[season], marginals)
end

"""
    __instantiate_distribution(name::String, params::Tuple)

Return an instance of a `Distributions.jl` distribution of type `name` with parameters `params`.
"""
function __instantiate_distribution(name::String, params::Tuple)::Distributions.UnivariateDistribution
    return getfield(Distributions, Symbol(name))(params...)
end

"""
    __instantiate_copula(name::String, params::Tuple)

Return an instance of a `Copulas.jl` copula of type `name` with parameters `params`.
"""
function __instantiate_copula(name::String, params::Tuple)::Copulas.Copula
    return getfield(Copulas, Symbol(name))(params...)
end
