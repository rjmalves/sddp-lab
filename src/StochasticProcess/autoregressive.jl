
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

    PeriodicARparameters(parameter_set)
end

# SIGNAL MODEL TYPE ------------------------------------------------------------------------

struct UnivariateAutoRegressive
    id::Int
    initial_values::Vector{Float64}
    model::AbstractARparameters
end

function UnivariateAutoRegressive(d::Dict{String, Any}, e::CompositeException)
    valid = __validate_univariateautoregressive_dict!(d, e)

    if !valid
        return nothing
    end

    arp = __build_ar_parameters(d, e)
    
    # TODO: validate that init is same size as maximum lag in models

    UnivariateAutoRegressive(d["id"], d["initial_values"], arp)
end

# MAIN AR TYPE -----------------------------------------------------------------------------

struct AutoRegressive <: AbstractStochasticProcess
    signal_model::Vector{UnivariateAutoRegressive}
    noise_model::Naive
end

function AutoRegressive(d::Dict{String, Any}, e::CompositeException)
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

    AutoRegressive(signal, noise)
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
    length(arp.phis)
end

function __get_lag(arp::PeriodicARparameters)
    max_lags = [__get_lag(i) for i in arp.parameter_set]
    maximum(max_lags)
end

function __get_lag(uar::UnivariateAutoRegressive)
    __get_lag(uar.model)
end

function __get_ar_parameters(arp::SimpleARparameters)
    arp.phis
end

function __get_ar_parameters(arp::SimpleARparameters, ::Int, ::Bool)
    __get_ar_parameters(arp)
end

function __get_ar_parameters(arp::PeriodicARparameters, season::Int, pad::Bool = false)
    seasons = map(x -> x.season, arp.parameter_set)
    index = findfirst(x -> x == season, seasons)
    if pad
        aux = __get_ar_parameters(arp.parameter_set[index])
        out = zeros(Float64, __get_lag(arp))
        for i in 1:length(aux)
            out[i] += aux[i]
        end
    else 
        out = __get_ar_parameters(arp.parameter_set[index])
    end
    return out
end

function __get_ar_parameters(uar::UnivariateAutoRegressive, season::Int, pad::Bool = false)
    __get_ar_parameters(uar.model, season, pad)
end

function __get_ar_parameters(s::AutoRegressive, season::Int, pad::Bool = false)
    [__get_ar_parameters(uar, season, pad) for uar in s.signal_model]
end

function __get_ar_scale(arp::SimpleARparameters)
    arp.scale
end

function __get_ar_scale(arp::SimpleARparameters, ::Int)
    __get_ar_scale(arp)
end

function __get_ar_scale(arp::PeriodicARparameters, season::Int)
    seasons = map(x -> x.season, arp.parameter_set)
    index = findfirst(x -> x == season, seasons)
    __get_ar_scale(arp.parameter_set[index])
end

function __get_ar_scale(uar::UnivariateAutoRegressive, season::Int)
    __get_ar_scale(uar.model, season)
end

function __get_ar_scale(s::AutoRegressive, season::Int)
    [__get_ar_scale(uar, season) for uar in s.signal_model]
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
    rng::AbstractRNG,
    s::AutoRegressive,
    initial_season::Integer,
    N::Integer,
    B::Integer)

    __generate_saa(rng, s.noise_model, initial_season, N, B)
    
end

function add_inflow_uncertainty!(m::JuMP.Model, s::AutoRegressive,
    season::Int)

    n_hydro, period, max_lags = size(s)
    stchp_size = sum(max_lags)
    
    scales = __get_ar_scale(s, season)
    inits = vcat([uar.initial_values for uar in s.signal_model]...)

    index_t = ones(Int,length(s))
    for i in 1:(length(s) - 1)
        index_t[i+1] = sum(max_lags[1:i]) + 1
    end
    memory_states = [n for n in 1:stchp_size if !(n in index_t)]
    
    m[ω_INFLOW] = @variable(m, [1:n_hydro], base_name = String(ω_INFLOW))
    m[STCHP] = @variable(m,
        [n = 1:stchp_size],
        base_name = String(STCHP),
        SDDP.State,
        initial_value = inits[n])

    lagged_scales = __get_lag_scales(s, season)
    ar_coefs = __get_ar_parameters(s, season, true)

    # main AR state transition (model)
    for (n, t) in enumerate(zip(ar_coefs, lagged_scales, index_t, max_lags))
        ar_c, l_s, i, m_l = t
        s_t = scales[n]
        @constraint(m,
            (m[STCHP][i].out - s_t[1]) / s_t[2] == 
                sum(ar_c[l] * (m[STCHP][i + l - 1].in - l_s[l][1]) / l_s[l][2] for l in 1:m_l) +
                m[ω_INFLOW][n],
            base_name = "ar_main" * string(n))
    end
    @constraint(m, inflow[n = 1:n_hydro], m[INFLOW][n] == m[STCHP][index_t[n]].out)

    # memory mapping of lags
    @constraint(m, ar_memory[n in memory_states], m[STCHP][n].out == m[STCHP][n - 1].in)

    return m
end

function __get_lag_scales(s::AutoRegressive, season::Int)
    lag_scales = []
    N, P, M_Ls = size(s)
    for n in 1:N
        aux = []
        for l in 1:M_Ls[n]
            ls = __lagged_season(season, l, P)
            push!(aux, __get_ar_scale(s.signal_model[n], ls))
        end
        push!(lag_scales, aux)
    end

    return lag_scales
end
