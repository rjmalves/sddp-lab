module StochasticProcess

using Random, Distributions, Copulas
using LinearAlgebra
using JuMP
using SDDP: SDDP
using ..Lab
using ..Utils

import Copulas: Copula
import Base: length, size

"""
    AbstractStochasticProcess

Abstract base type for inflow stochastic processes. Concrete subtypes:
[`Naive`](@ref), [`AutoRegressive`](@ref), [`VectorAutoRegressive`](@ref).

All subtypes must implement `__generate_saa` (internal) for SAA generation and
`add_inflow_uncertainty!` for adding uncertainty to SDDP subproblems.

See also: [`generate_saa`](@ref)
"""
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

"""
    generate_saa(s, initial_season, N, B) -> Vector{Vector{Vector{Float64}}}

Generate a Sample Average Approximation (SAA) of size `N × B` from stochastic
process `s`, starting at season `initial_season`.

Uses Julia's default (global) RNG. For reproducible results, use the
`generate_saa(s, initial_season, N, B, seed)` overload.

# Arguments

  - `s`: An [`AbstractStochasticProcess`](@ref) instance.
  - `initial_season`: Season index (1-based) for the first stage.
  - `N`: Number of stages.
  - `B`: Number of scenario branchings per stage.

# Returns

A `Vector{Vector{Vector{Float64}}}` with shape `[N][B][num_hydros]`.

See also: [`Naive`](@ref), [`AutoRegressive`](@ref), [`VectorAutoRegressive`](@ref)
"""
function generate_saa(
    s::AbstractStochasticProcess, initial_season::Integer, N::Integer, B::Integer
)::Vector{Vector{Vector{Float64}}}
    return __generate_saa(Random.default_rng(), s, initial_season, N, B)
end

"""
    generate_saa(s, initial_season, N, B, seed) -> Vector{Vector{Vector{Float64}}}

Generate a reproducible SAA of size `N × B` using the given `seed`.

Creates a fresh `MersenneTwister` RNG from `seed`, ensuring deterministic
output independent of global RNG state.

# Arguments

  - `s`: An [`AbstractStochasticProcess`](@ref) instance.
  - `initial_season`: Season index (1-based) for the first stage.
  - `N`: Number of stages.
  - `B`: Number of scenario branchings per stage.
  - `seed`: Integer random seed for the `MersenneTwister` RNG.

# Example

```julia
saa = generate_saa(process, 1, 60, 10, 42)
length(saa)      # 60 stages
length(saa[1])   # 10 branchings
```

See also: [`AbstractStochasticProcess`](@ref)
"""
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
