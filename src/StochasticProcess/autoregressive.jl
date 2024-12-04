
# INTERNAL AR TYPES ------------------------------------------------------------------------

abstract type AbstractARparameters end

function __build_ar_parameters(d, e)
    if length(d["models"]) == 1
        SimpleARparameters(d, e)
    else
        PeriodicARparameters(d, e)
    end
end

struct SimpleARparameters <: AbstractARparameters
    parameters::Vector{Float64}
    scale::Vector{Float64}
    season::Int
end

function SimpleARparameters(d, e)
    # __validate_ar_parameters(d, e)
    #     - checa se tem as chaves season, coefs, res_var e scale_par e sao dos tipos certos

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
    # valid = __validate_univariateautoregressive_dict(d, e)
    #     - chaves id, init e models existem e sao dos tipos certos

    if !valid
        return nothing
    end

    arp = __build_ar_parameters(d["models"], e)

    UnivariateAutoRegressive(d["id"], d["initialization"], arp)
end

# MAIN AR TYPE -----------------------------------------------------------------------------

struct AutoRegressiveStochasticProcess <: AbstractStochasticProcess
    signal_model::Vector{UnivariateAutoRegressive}
    noise_model::Naive
end

function AutoRegressiveStochasticProcess(d::Dict{String, Any}, e::CompositeException)
    # valid = __validate_autoregressive_dict(d, e)
    #     - so checa se existem as chaves "marginal_models" e "copulas" e sao Dicts
    return if !valid
        nothing
    end

    signal = Dict{Int,UnivariateAutoRegressive}()
    for marginal_model in d["marginal_models"]
        s = UnivariateAutoRegressive(marginal_model, e)
        signal[d["id"]] = (signal, s)
    end

    noise_dict = __build_noise_naive_dict(d, e)
    noise = Naive(d, e)
end
