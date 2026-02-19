"""
    AbstractMarkovChain

Abstract base type for Markov chain state-transition configurations. Subtypes:
[`NoMarkovChain`](@ref), [`MarkovChainConfig`](@ref).

See also: [`ScenariosData`](@ref), [`has_markov_chain`](@ref)
"""
abstract type AbstractMarkovChain end

"""
    NoMarkovChain <: AbstractMarkovChain

Sentinel type indicating that no Markov chain is used. The inflow process is
a single stationary stochastic process.

See also: [`MarkovChainConfig`](@ref), [`has_markov_chain`](@ref)
"""
struct NoMarkovChain <: AbstractMarkovChain end

function NoMarkovChain(::Dict{String,Any}, ::CompositeException)
    return NoMarkovChain()
end

"""
    MarkovChainConfig <: AbstractMarkovChain

Configuration for a first-order Markov chain governing inflow regime transitions.
Each stage has a transition matrix whose columns define the target state
probabilities.

# Fields
- `transition_matrices`: Ordered vector of `num_states × num_states` transition
  matrices, one per stage. Entry `[i, j]` is the probability of moving from
  state `i` to state `j`.
- `num_states`: Number of Markov states (inferred from the first matrix).

See also: [`NoMarkovChain`](@ref), [`has_markov_chain`](@ref),
[`num_markov_states`](@ref)
"""
struct MarkovChainConfig <: AbstractMarkovChain
    transition_matrices::Vector{Matrix{Float64}}
    num_states::Int
end

function MarkovChainConfig(d::Dict{String,Any}, e::CompositeException)
    valid_keys = __validate_markov_chain_keys_types!(d, e)
    valid_content = valid_keys && __validate_transition_matrices!(d, e)

    return if valid_content
        matrices = d["transition_matrices"]
        # num_states is the number of columns of the first (root) matrix
        num_states = size(matrices[1], 2)
        MarkovChainConfig(matrices, num_states)
    else
        nothing
    end
end

"""
    has_markov_chain(mc) -> Bool

Return `true` if `mc` represents an active Markov chain (i.e., is a
[`MarkovChainConfig`](@ref)), `false` for [`NoMarkovChain`](@ref).
"""
has_markov_chain(::NoMarkovChain) = false
has_markov_chain(::MarkovChainConfig) = true

"""
    num_markov_states(mc) -> Int

Return the number of Markov states. Returns `1` for [`NoMarkovChain`](@ref).

See also: [`MarkovChainConfig`](@ref)
"""
num_markov_states(::NoMarkovChain) = 1
num_markov_states(mc::MarkovChainConfig) = mc.num_states

num_stages(mc::MarkovChainConfig) = length(mc.transition_matrices)
