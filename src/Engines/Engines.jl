module Engines

using ..Core
using ..System

using DataFrames
using SDDP: SDDP
using JuMP: JuMP
import MathOptInterface as MOI

# SDDP TYPES

struct SDDPModel <: Model
    policy_graph::SDDP.PolicyGraph
end

abstract type StoppingCriteria end

struct IterationLimit <: StoppingCriteria
    num_iterations::Integer
end

struct TimeLimit <: StoppingCriteria
    time_seconds::Integer
end

struct LowerBoundStability <: StoppingCriteria
    threshold::Real
    num_iterations::Integer
end

struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::StoppingCriteria
end

abstract type ParallelScheme end

struct Serial <: ParallelScheme end

struct Asynchronous <: ParallelScheme end

abstract type RiskMeasure end

struct Expectation <: RiskMeasure end

struct WorstCase <: RiskMeasure end

struct AVaR <: RiskMeasure
    alpha::Real
end

struct CVaR <: RiskMeasure
    alpha::Real
    lambda::Real
end

struct SDDPPolicyTaskDefinition <: PolicyTaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
end

struct SDDPPolicyTaskArtifact <: PolicyTaskArtifact
    policy::SDDP.PolicyGraph
    files::Vector{InputModule}
end

struct SDDPSimulationTaskDefinition <: SimulationTaskDefinition
    num_simulated_series::Integer
    parallel_scheme::ParallelScheme
end

struct SDDPSimulationTaskArtifact <: SimulationTaskArtifact
    definition::SDDPSimulationTaskDefinition
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    files::Vector{InputModule}
end

struct SDDPEngine <: Engine
    policy::SDDPPolicyTaskDefinition
    simulation::SDDPSimulationTaskDefinition
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
get_policy_definition(e::Engine)::PolicyTaskDefinition

Return the policy definition for a specific engine
"""
function get_policy_definition(e::Engine)::PolicyTaskDefinition end

"""
get_simulation_definition(e::Engine)::SimulationTaskDefinition

Return the simulation definition for a specific engine
"""
function get_simulation_definition(e::Engine)::SimulationTaskDefinition end

# INTERNALS ------------------------------------------------------------------------

include("sddp.jl")
include("input.jl")
include("input-validators.jl")

export SDDPEngine

end