module Engines

using ..Core

using SDDP: SDDP


# SDDP TYPES

struct SDDPEngine <: Engine end

struct SDDPModel <: Model
    policy_graph::SDDP.PolicyGraph
end

struct SDDPPolicyTaskDefinition <: PolicyTaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
end
struct SDDPPolicyTaskArtifact <: PolicyTaskArtifact
    definition::SDDPPolicyTaskDefinition
    policy::SDDP.PolicyGraph
    files::Vector{InputModule}
end

struct SDDPSimulationTaskDefinition <: SimulationTaskDefinition
    num_simulated_series::Integer
    policy::SimulationTaskPolicy
    parallel_scheme::ParallelScheme
end
struct SDDPSimulationTaskArtifact <: SimulationTaskArtifact
    definition::SDDPSimulationTaskDefinition
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    files::Vector{InputModule}
end


include("sddp.jl")

export SDDP

end