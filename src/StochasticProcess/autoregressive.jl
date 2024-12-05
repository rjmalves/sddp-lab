
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
        push!(parameter_set, model)
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

function __get_ar_parameters(arp::SimpleARparameters, ::Int)
    __get_ar_parameters(arp)
end

function __get_ar_parameters(arp::PeriodicARparameters, season::Int)
    seasons = map(x -> x.season, arp.parameter_set)
    index = findfirst(x -> x == season, seasons)
    __get_ar_parameters(arp.parameter_set[index])
end

function __get_ar_parameters(uar::UnivariateAutoRegressive, season::Int)
    __get_ar_parameters(uar.model, season)
end

function __get_ar_parameters(s::AutoRegressiveStochasticProcess, season::Int)
    [__get_ar_parameters(uar, season) for uar in s.signal_model]
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

function __get_ar_scale(s::AutoRegressiveStochasticProcess, season::Int)
    [__get_ar_scale(uar, season) for uar in s.signal_model]
end

function length(s::AutoRegressiveStochasticProcess)::Integer
    return length(s.signal_model)
end

# SDDP METHODS -----------------------------------------------------------------------------

function __generate_saa(
    rng::AbstractRNG,
    s::AutoRegressiveStochasticProcess,
    initial_season::Integer,
    N::Integer,
    B::Integer)

    __generate_saa(rng, s.noise_model, initial_season, N, B)
    
end

function add_inflow_uncertainty!(m::JuMP.Model, s::AutoRegressiveStochasticProcess,
    season::Int)

    n_hydro = length(s)
    max_lags = [__get_lag(i) for i in s.signal_model]
    stchp_size = sum(max_lags)
    
    scales = __get_ar_scale(s, season)
    inits = vcat([uar.initial_values for uar in s.signal_model]...)

    index_t = ones(Int,length(s))
    for i in 1:(length(s) - 1)
        index_t[i+1] = sum(max_lags[1:i]) + 1
    end

    st_mat = __build_state_transition_matrix(s, season, max_lags)
    sel_mat = __build_selector_matrix(index_t, n_hydro)

    m[ω_INFLOW] = @variable(m, [1:n_hydro], base_name = String(ω_INFLOW))
    m[STCHP] = @variable(m,
        [n = 1:stchp_size],
        base_name = String(STCHP),
        SDDP.State,
        initial_value = inits[n])

    @constraint(m, ar_model[n = 1:stchp_size], 
        m[STCHP][n].out == st_mat[n,:]' * [var.in for var in m[STCHP]] + sel_mat[n,:]' * m[ω_INFLOW])
    @constraint(m, inflow_model[n = 1:n_hydro],
        m[INFLOW][n] .== m[STCHP][index_t[n]].out  * scales[n][2] + scales[n][1])

    return m
end

function __arp2statematrix(phis::Vector{T} where T <: Real, size::Int)

    out = zeros((size, size))

    for i in 1:length(phis)
        out[1, i] = phis[i]
    end

    for i in 2:size
        out[i, i-1] = 1
    end

    return out

end

function __block_diagonal_matrix(matrices::Vector{Matrix{T}} where T <: Real)
    
    sizes = [size(m, 1) for m in matrices]
    full_size = sum(sizes)
    
    offsets = zeros(Int, length(matrices))
    for i in 1:(length(offsets) - 1)
        offsets[i+1] = sum(sizes[1:i])
    end

    out = zeros(full_size, full_size)
    for k in 1:length(matrices)
        offset = offsets[k]
        m = matrices[k]
        for i in 1:sizes[k], j in 1:sizes[k]
            out[offset + i, offset + j] = m[i, j]
        end
    end

    return out
end

function __build_state_transition_matrix(s::AutoRegressiveStochasticProcess, season::Int,
    max_lags::Vector{Int})

    st_mat = __get_ar_parameters(s, season)
    st_mat = [__arp2statematrix(m, l) for (m,l) in zip(st_mat, max_lags)]
    st_mat = __block_diagonal_matrix(st_mat)
    
    return st_mat
end

function __build_selector_matrix(Is::Vector{Int}, J)
    I = sum(Is)
    sel_mat = zeros(Int, (I, J))

    for (i,j) in zip(Is, 1:J)
        sel_mat[i,j] = 1
    end

    return sel_mat
end