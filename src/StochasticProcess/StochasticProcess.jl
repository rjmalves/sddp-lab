module StochasticProcess

using Random, Distributions, Copulas
using LinearAlgebra
using JuMP
using SDDP: SDDP
using ..Lab
using ..Utils

import Copulas: Copula
import Base: length, size

abstract type AbstractStochasticProcess end

function __get_ids(s::AbstractStochasticProcess)::Vector{Integer} end
function length(s::AbstractStochasticProcess)::Integer end
function size(s::AbstractStochasticProcess)::Tuple{Integer,Vararg{Integer}} end

function __generate_saa(
    rng::AbstractRNG,
    s::AbstractStochasticProcess,
    initial_season::Integer,
    N::Integer,
    B::Integer,
)::Vector{Vector{Vector{Float64}}} end

function generate_saa(
    s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer
)::Vector{Vector{Vector{Float64}}}
    return __generate_saa(Random.default_rng(), s, initial_season, N, B)
end

function generate_saa(
    s::AbstractStochasticProcess,
    initial_season::Integer,
    N::Integer,
    B::Integer,
    seed::Integer,
)::Vector{Vector{Vector{Float64}}}
    rng = Random.MersenneTwister(seed)
    return __generate_saa(rng, s, initial_season, N, B)
end

function add_inflow_uncertainty!(m::JuMP.Model, s::AbstractStochasticProcess)::nothing end
function __validate(s::AbstractStochasticProcess) end

function __cast_stochastic_process_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    stochastic_process_d = d["stochastic_process"]
    valid_file_key = __validate_file_key!(stochastic_process_d, e)
    valid = valid_file_key && __validate_cast_from_jsonc_file!(stochastic_process_d, e)
    return valid
end

include("naive-validators.jl")
include("naive.jl")

include("autoregressive-validators.jl")
include("autoregressive.jl")

include("vectorautoregressive-validators.jl")
include("vectorautoregressive.jl")

export Naive,
    AutoRegressive,
    VectorAutoRegressive,
    get_ar_parameters,
    get_ar_scale,
    get_var_season_parameters,
    get_var_coefficient_matrix,
    get_var_scales,
    AbstractStochasticProcess,
    __cast_stochastic_process_internals_from_files!

end