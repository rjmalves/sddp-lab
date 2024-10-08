module Engines

using SDDP: SDDP

# TYPES ------------------------------------------------------------------------

abstract type AbstractEngine end

struct SDDPEngine <: AbstractEngine end
struct RawMatrixEngine <: AbstractEngine end

abstract type AbstractModel end

struct SDDPModel <: AbstractModel
    policy_graph::SDDP.PolicyGraph
end

struct RawMatrixModel <: AbstractModel
    # TODO
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
build_model(engine)

Builds the model as expected by a given engine.
"""
function build_model(engine::AbstractEngine)::AbstractModel end

"""
train_model(model)

Trains the model as expected by a given engine.
"""
function train_model(model::AbstractModel) end

"""
simulate_model(model)

Simulate the model as expected by a given engine.
"""
function simulate_model(model::AbstractModel) end

export AbstractEngine, SDDPEngine, RawMatrixEngine

end