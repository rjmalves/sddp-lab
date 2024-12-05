
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
    parameters::Vector{Float64}
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
    parameters::Vector{SimpleARparameters}
end

function PeriodicARparameters(v, e)
    parameters = Vector{SimpleARparameters}()
    for model_dict in v
        model = SimpleARparameters(model_dict, e)
        push!(parameters, model)
    end

    PeriodicARparameters(parameters)
end

# SIGNAL MODEL TYPE ------------------------------------------------------------------------

struct UnivariateAutoRegressive
    id::Int
    initialization::Vector{Float64}
    parameters::AbstractARparameters
end

function UnivariateAutoRegressive(d::Dict{String, Any}, e::CompositeException)
    valid = __validate_univariateautoregressive_dict!(d, e)

    if !valid
        return nothing
    end

    arp = __build_ar_parameters(d, e)

    UnivariateAutoRegressive(d["id"], d["initial_values"], arp)
end

# MAIN AR TYPE -----------------------------------------------------------------------------

struct AutoRegressiveStochasticProcess <: AbstractStochasticProcess
    signal_model::Vector{UnivariateAutoRegressive}
    noise_model::Naive
end

function AutoRegressiveStochasticProcess(d::Dict{String, Any}, e::CompositeException)
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

    AutoRegressiveStochasticProcess(signal, noise)
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

function __get_ids(s::AutoRegressiveStochasticProcess)
    return map(x -> x.id, values(s.signal_model))
end

function __get_lag(ar::SimpleARparameters)
    length(ar.parameters)
end

function __get_lag(ar::PeriodicARparameters)
    max_lags = [__get_lag(i) for i in ar.parameters]
    maximum(max_lags)
end

function __get_lag(ar::UnivariateAutoRegressive)
    __get_lag(ar.parameters)
end

function length(s::AutoRegressiveStochasticProcess)::Integer
    return length(s.signal_model)
end

function size(s::AutoRegressiveStochasticProcess)::Tuple
    # return (n_ids, n_seasons, Vector{max_lag_per_id})
end

# SDDP METHODS -----------------------------------------------------------------------------

function __generate_saa(
    rng::AbstractRNG,
    s::AutoRegressiveStochasticProcess,
    initial_season::Integer,
    N::Integer,
    B::Integer)::Vector{Vector{Vector{Float64}}}

    __generate_saa(rng, s.noise_model, initial_season, N, B)
    
end
