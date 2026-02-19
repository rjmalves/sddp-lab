abstract type AbstractMarkovChain end

struct NoMarkovChain <: AbstractMarkovChain end

function NoMarkovChain(::Dict{String,Any}, ::CompositeException)
    return NoMarkovChain()
end

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

has_markov_chain(::NoMarkovChain) = false
has_markov_chain(::MarkovChainConfig) = true

num_markov_states(::NoMarkovChain) = 1
num_markov_states(mc::MarkovChainConfig) = mc.num_states

num_stages(mc::MarkovChainConfig) = length(mc.transition_matrices)
