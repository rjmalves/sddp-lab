
# INTERNAL AR TYPES ------------------------------------------------------------------------

abstract type AbstractARparameters end

function __build_ar_parameters(d, e)
    if length(d["models"]) == 1
        SimpleARparameters(d["models"][1], e)
    else
        PeriodicARparameters(d["models"], e)
    end
end

struct SimpleARparameters <: AbstractARparameters
    phis::Vector{Float64}
    scale::Vector{Float64}
    season::Int
end

function SimpleARparameters(d, e)
    valid = __validate_ar_parameters_dict!(d, e)

    return if valid
        SimpleARparameters(d["coefficients"], d["scale_parameters"], d["season"])
    else
        nothing
    end
end

struct PeriodicARparameters <: AbstractARparameters
    parameter_set::Vector{SimpleARparameters}
end

function PeriodicARparameters(v, e)
    parameter_set = Vector{SimpleARparameters}()
    for model_dict in v
        model = SimpleARparameters(model_dict, e)
        if !isnothing(model)
            push!(parameter_set, model)
        end
    end

    return PeriodicARparameters(parameter_set)
end

# SIGNAL MODEL TYPE ------------------------------------------------------------------------

struct UnivariateAutoRegressive
    id::Int
    initial_values::Vector{Float64}
    model::AbstractARparameters
end

function UnivariateAutoRegressive(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_univariateautoregressive_dict!(d, e)

    if !valid
        return nothing
    end

    arp = __build_ar_parameters(d, e)

    # TODO: validate that init is same size as maximum lag in models

    return UnivariateAutoRegressive(d["id"], d["initial_values"], arp)
end

# MAIN AR TYPE -----------------------------------------------------------------------------

"""
    AutoRegressive <: AbstractStochasticProcess

Univariate AR(p) model for each hydro reservoir with seasonal parameters and
a residual [`Naive`](@ref) noise model. Suitable for single-site inflow
modeling when inter-site correlations are captured through the noise copula.

# Fields

  - `signal_model`: Vector of per-hydro `UnivariateAutoRegressive` AR process
    definitions.
  - `noise_model`: [`Naive`](@ref) process for the residual noise term.

See also: [`VectorAutoRegressive`](@ref), [`generate_saa`](@ref),
[`get_ar_parameters`](@ref), [`get_ar_scale`](@ref)
"""
struct AutoRegressive <: AbstractStochasticProcess
    signal_model::Vector{UnivariateAutoRegressive}
    noise_model::Naive
end

function AutoRegressive(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_autoregressive_dict!(d, e)

    if !valid
        return nothing
    end

    signal = Vector{UnivariateAutoRegressive}()
    for marginal_model in d["marginal_models"]
        s = UnivariateAutoRegressive(marginal_model, e)
        push!(signal, s)
    end

    noise_dict = __build_noise_naive_dict(d)
    noise = Naive(d, e)

    return AutoRegressive(signal, noise)
end

function __build_noise_naive_dict(d)
    naive_dict = copy(d)

    for marg_mod in naive_dict["marginal_models"]
        delete!(marg_mod, "initial_values")

        for mod in marg_mod["models"]
            delete!(mod, "scale_parameters")
            delete!(mod, "coefficients")
            mod["kind"] = "Gaussian"
            mod["parameters"] = [0.0, sqrt(pop!(mod, "residual_variance"))]
        end

        marg_mod["distributions"] = pop!(marg_mod, "models")
    end

    return naive_dict
end

# GENERAL METHODS --------------------------------------------------------------------------

function __get_ids(s::AutoRegressive)
    return map(x -> x.id, values(s.signal_model))
end

function __get_lag(arp::SimpleARparameters)
    return length(arp.phis)
end

function __get_lag(arp::PeriodicARparameters)
    max_lags = [__get_lag(i) for i in arp.parameter_set]
    return maximum(max_lags)
end

function __get_lag(uar::UnivariateAutoRegressive)
    return __get_lag(uar.model)
end

"""
    get_ar_parameters(s, season, pad) -> Vector{Float64}

Return the AR coefficient vector (phi values) for season `season` from an
[`AutoRegressive`](@ref) process or its component types.

When `pad = true`, the returned vector is padded with zeros to the maximum lag
length across all seasons, ensuring consistent dimensions.

See also: [`get_ar_scale`](@ref), [`AutoRegressive`](@ref)
"""
function get_ar_parameters(arp::SimpleARparameters)
    return arp.phis
end

function get_ar_parameters(arp::SimpleARparameters, ::Int, ::Bool)
    return get_ar_parameters(arp)
end

function get_ar_parameters(arp::PeriodicARparameters, season::Int, pad::Bool = false)
    seasons = map(x -> x.season, arp.parameter_set)
    index = findfirst(x -> x == season, seasons)
    if pad
        aux = get_ar_parameters(arp.parameter_set[index])
        out = zeros(Float64, __get_lag(arp))
        for i in 1:length(aux)
            out[i] += aux[i]
        end
    else
        out = get_ar_parameters(arp.parameter_set[index])
    end
    return out
end

function get_ar_parameters(uar::UnivariateAutoRegressive, season::Int, pad::Bool = false)
    return get_ar_parameters(uar.model, season, pad)
end

function get_ar_parameters(s::AutoRegressive, season::Int, pad::Bool = false)
    return [get_ar_parameters(uar, season, pad) for uar in s.signal_model]
end

"""
    get_ar_scale(s, season) -> Vector{Float64}

Return the scaling parameters (mean and standard deviation) for season `season`
from an [`AutoRegressive`](@ref) process or its component types.

See also: [`get_ar_parameters`](@ref), [`AutoRegressive`](@ref)
"""
function get_ar_scale(arp::SimpleARparameters)
    return arp.scale
end

function get_ar_scale(arp::SimpleARparameters, ::Int)
    return get_ar_scale(arp)
end

function get_ar_scale(arp::PeriodicARparameters, season::Int)
    seasons = map(x -> x.season, arp.parameter_set)
    index = findfirst(x -> x == season, seasons)
    return get_ar_scale(arp.parameter_set[index])
end

function get_ar_scale(uar::UnivariateAutoRegressive, season::Int)
    return get_ar_scale(uar.model, season)
end

function get_ar_scale(s::AutoRegressive, season::Int)
    return [get_ar_scale(uar, season) for uar in s.signal_model]
end

function length(ar::SimpleARparameters)
    return 1
end

function length(ar::PeriodicARparameters)
    return length(ar.parameter_set)
end

function length(s::AutoRegressive)
    return length(s.signal_model)
end

function size(s::AutoRegressive)
    s1 = length(s)
    period = maximum([length(uar.model) for uar in s.signal_model])
    max_lags = [__get_lag(uar) for uar in s.signal_model]

    return (s1, period, max_lags)
end

function size(s::AutoRegressive, i::Int)
    return size(s)[i]
end

# SDDP METHODS -----------------------------------------------------------------------------

function __generate_saa(
    rng::AbstractRNG, s::AutoRegressive, initial_season::Integer, N::Integer, B::Integer
)
    return __generate_saa(rng, s.noise_model, initial_season, N, B)
end
