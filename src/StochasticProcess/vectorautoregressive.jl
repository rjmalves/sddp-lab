
struct VARSeasonParameters
    coefficient_matrices::Vector{Matrix{Float64}}
    scales::Vector{Vector{Float64}}
    season::Int
end

"""
    VectorAutoRegressive <: AbstractStochasticProcess

VAR(p) process for multivariate inflow modeling. The recurrence in normalized space is:

    (X_t[n] - mu_s[n]) / sigma_s[n] = sum_{l=1}^{p} sum_{m=1}^{N} Phi_{s,l}[n,m] *
        (X_{t-l}[m] - mu_{s-l}[m]) / sigma_{s-l}[m] + omega_t[n]

where s is the season and Phi_{s,l} is the N x N coefficient matrix for season s, lag l.
"""
struct VectorAutoRegressive <: AbstractStochasticProcess
    season_parameters::Dict{Int,VARSeasonParameters}
    noise_model::Naive
    ids::Vector{Int}
    initial_values::Vector{Vector{Float64}}
    max_lag::Int
    num_seasons::Int
end

function VectorAutoRegressive(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_vectorautoregressive_dict!(d, e)
    if !valid
        return nothing
    end

    ids = Int[mm["id"] for mm in d["marginal_models"]]
    initial_values = Vector{Float64}[mm["initial_values"] for mm in d["marginal_models"]]

    coef_entries = d["coefficient_matrices"]
    season_lag_matrices = Dict{Int,Dict{Int,Matrix{Float64}}}()
    for entry in coef_entries
        s = entry["season"]
        l = entry["lag"]
        mat = Float64.(hcat([Float64.(row) for row in entry["matrix"]]...)')
        if !haskey(season_lag_matrices, s)
            season_lag_matrices[s] = Dict{Int,Matrix{Float64}}()
        end
        season_lag_matrices[s][l] = mat
    end

    max_lag = maximum(maximum(keys(lags)) for (_, lags) in season_lag_matrices)
    seasons = sort(collect(keys(season_lag_matrices)))
    num_seasons = length(seasons)

    season_scales = Dict{Int,Vector{Vector{Float64}}}()
    for mm in d["marginal_models"]
        for model in mm["models"]
            s = model["season"]
            if !haskey(season_scales, s)
                season_scales[s] = Vector{Vector{Float64}}()
            end
            push!(season_scales[s], model["scale_parameters"])
        end
    end

    season_parameters = Dict{Int,VARSeasonParameters}()
    for s in seasons
        lag_matrices = season_lag_matrices[s]
        mats = Matrix{Float64}[lag_matrices[l] for l in 1:max_lag]
        scales = season_scales[s]
        season_parameters[s] = VARSeasonParameters(mats, scales, s)
    end

    noise_dict = __build_var_noise_naive_dict(d)
    noise = Naive(noise_dict, e)

    return VectorAutoRegressive(
        season_parameters, noise, ids, initial_values, max_lag, num_seasons
    )
end

# Transforms the VAR params dict into a Naive-compatible dict for noise model construction.
# Follows the same pattern as __build_noise_naive_dict in autoregressive.jl.
function __build_var_noise_naive_dict(d::Dict{String,Any})
    naive_dict = deepcopy(d)
    delete!(naive_dict, "coefficient_matrices")

    for marg_mod in naive_dict["marginal_models"]
        delete!(marg_mod, "initial_values")

        for mod in marg_mod["models"]
            delete!(mod, "scale_parameters")
            mod["kind"] = "Gaussian"
            mod["parameters"] = [0.0, sqrt(pop!(mod, "residual_variance"))]
        end

        marg_mod["distributions"] = pop!(marg_mod, "models")
    end

    return naive_dict
end

function __get_ids(s::VectorAutoRegressive)
    return copy(s.ids)
end

function length(s::VectorAutoRegressive)::Integer
    return length(s.ids)
end

function size(s::VectorAutoRegressive)::Tuple{Integer,Vararg{Integer}}
    return (length(s.ids), s.num_seasons, s.max_lag)
end

function size(s::VectorAutoRegressive, i::Int)
    return size(s)[i]
end

"""
    get_var_season_parameters(s, season) -> VARSeasonParameters

Return the `VARSeasonParameters` for season `season` from a
[`VectorAutoRegressive`](@ref) process.

See also: [`get_var_coefficient_matrix`](@ref), [`get_var_scales`](@ref)
"""
function get_var_season_parameters(s::VectorAutoRegressive, season::Int)
    return s.season_parameters[season]
end

"""
    get_var_coefficient_matrix(s, season, lag) -> Matrix{Float64}

Return the `N × N` VAR coefficient matrix for season `season` at lag `lag`
from a [`VectorAutoRegressive`](@ref) process.

See also: [`get_var_season_parameters`](@ref), [`VectorAutoRegressive`](@ref)
"""
function get_var_coefficient_matrix(s::VectorAutoRegressive, season::Int, lag::Int)
    return s.season_parameters[season].coefficient_matrices[lag]
end

"""
    get_var_scales(s, season) -> Vector{Vector{Float64}}

Return the per-hydro scaling parameter vectors (mean and std) for season
`season` from a [`VectorAutoRegressive`](@ref) process.

See also: [`get_var_coefficient_matrix`](@ref), [`VectorAutoRegressive`](@ref)
"""
function get_var_scales(s::VectorAutoRegressive, season::Int)
    return s.season_parameters[season].scales
end

function __generate_saa(
    rng::AbstractRNG,
    s::VectorAutoRegressive,
    initial_season::Integer,
    N::Integer,
    B::Integer,
)
    return __generate_saa(rng, s.noise_model, initial_season, N, B)
end
