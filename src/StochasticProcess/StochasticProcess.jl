module StochasticProcess

using Distributions, Copulas
using LinearAlgebra

import Copulas: Copula
import Base: length

abstract type AbstractStochasticProcess end

"""
    __get_ids(s)

Return the `id`s of elements represented in a stochastic process object
"""
__get_ids(s::AbstractStochasticProcess)

"""
    length(s::AbstractStochasticProcess)

Return the number of dimensions (elements) in a stochastic process
"""
length(s::AbstractStochasticProcess)

"""
    __validate(s::AbstractStochasticProcess)

Return `true` if `s` is a valid instance of stochastic process; raise errors otherwise
"""
__validate(s::AbstractStochasticProcess)

include("naive.jl")

end