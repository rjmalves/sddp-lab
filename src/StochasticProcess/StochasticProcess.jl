module StochasticProcess

using Random, Distributions, Copulas
using LinearAlgebra
using JuMP

import Copulas: Copula
import Base: length, size

abstract type AbstractStochasticProcess end

"""
    __get_ids(s)

Return the `id`s of elements represented in a stochastic process object
"""
function __get_ids(s::AbstractStochasticProcess) end

"""
    length(s::AbstractStochasticProcess)

Return the number of dimensions (elements) in a stochastic process
"""
function length(s::AbstractStochasticProcess) end

"""
    size(s::AbstractStochasticProcess)

Return the size of the process, a tuple with (number_of_elements, number_of_seasons[,...])

Depending on the type of model, it is possible that there are extra elements in the returned
tuple, so refer to the corresponding documentation for more details
"""
function size(s::AbstractStochasticProcess) end

"""
    generate_saa([rng::AbstractRNG, ]s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer)

Generate a Sample Average Approximation of the noise (uncertainty) terms in model `s`
"""
function generate_saa(rng::AbstractRNG, s::AbstractStochasticProcess, initial_season::Integer,
    N::Integer, B::Integer)
end

function generate_saa(s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer)
    generate_saa(Random.default_rng(), s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer)
end

"""
    add_inflow_uncertainty!(m, s)

Add stochastic variables and inflow model recurrence constraints to a JuMP model `m`
"""
function add_inflow_uncertainty!(m::JuMP.Model, s::AbstractStochasticProcess) end

"""
    __validate(s::AbstractStochasticProcess)

Return `true` if `s` is a valid instance of stochastic process; raise errors otherwise
"""
function __validate(s::AbstractStochasticProcess) end

include("naive.jl")

end