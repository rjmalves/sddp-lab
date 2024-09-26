module StochasticProcess

using Random, Distributions, Copulas
using LinearAlgebra
using JuMP
using ..Core
using ..Utils

import Copulas: Copula
import Base: length, size

abstract type AbstractStochasticProcess end

"""
    __get_ids(s)

Return the `id`s of elements represented in a stochastic process object
"""
function __get_ids(s::AbstractStochasticProcess)::Vector{Integer} end

"""
    length(s::AbstractStochasticProcess)

Return the number of dimensions (elements) in a stochastic process
"""
function length(s::AbstractStochasticProcess)::Integer end

"""
    size(s::AbstractStochasticProcess)

Return the size of the process, a tuple with (number_of_elements, number_of_seasons[,...])

Depending on the type of model, it is possible that there are extra elements in the returned
tuple, so refer to the corresponding documentation for more details
"""
function size(s::AbstractStochasticProcess)::Tuple{Integer, Vararg{Integer}} end

"""
    generate_saa([rng::AbstractRNG, ]s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer)

Generate a Sample Average Approximation of the noise (uncertainty) terms in model `s`
"""
function __generate_saa(
    rng::AbstractRNG,
    s::AbstractStochasticProcess,
    initial_season::Integer,
    N::Integer,
    B::Integer,
)::Vector{Vector{Vector{Float64}}}
end

function generate_saa(
    s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer
)::Vector{Vector{Vector{Float64}}}
    return __generate_saa(Random.default_rng(), s, initial_season, N, B)
end

"""
    add_inflow_uncertainty!(m, s)

Add stochastic variables and inflow model recurrence constraints to a JuMP model `m`
"""
function add_inflow_uncertainty!(m::JuMP.Model, s::AbstractStochasticProcess)::nothing end

"""
    __validate(s::AbstractStochasticProcess)

Return `true` if `s` is a valid instance of stochastic process; raise errors otherwise
"""
function __validate(s::AbstractStochasticProcess) end

include("naive.jl")

function __cast_stochastic_process_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    stochastic_process_d = d["stochastic_process"]
    valid_file_key = __validate_file_key!(stochastic_process_d, e)
    valid = valid_file_key && __validate_cast_from_jsonc_file!(stochastic_process_d, e)
    return valid
end

export Naive,
    AbstractStochasticProcess,
    generate_saa,
    add_inflow_uncertainty!,
    __cast_stochastic_process_internals_from_files!

end