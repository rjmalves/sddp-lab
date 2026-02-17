module Engines

using ..Lab
using ..StochasticProcess
using ..Scenarios
using ..System
using ..Utils

using DataFrames
using SDDP: SDDP
using JuMP: JuMP
using JSON
using CSV
using GLPK: GLPK
import MathOptInterface as MOI

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

struct Statistical <: StoppingCriteria
    num_replications::Integer
    iteration_period::Integer
    z_score::Real
end

struct SimulationStopping <: StoppingCriteria
    replications::Integer
    period::Integer
end

struct FirstStageStopping <: StoppingCriteria
    atol::Real
    iterations::Integer
end

struct StoppingChain <: StoppingCriteria
    rules::Vector{StoppingCriteria}
end

struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::Vector{StoppingCriteria}
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

struct Entropic <: RiskMeasure
    theta::Real
end

struct WassersteinRM <: RiskMeasure
    alpha::Real
end

struct ModifiedChiSquared <: RiskMeasure
    radius::Real
    minimum_std::Real
end

struct ConvexCombination <: RiskMeasure
    measures::Vector{Tuple{Real,RiskMeasure}}
end

abstract type SamplingScheme end

struct DefaultSampling <: SamplingScheme end

struct InSampleMC <: SamplingScheme
    max_depth::Integer
    terminate_on_dummy_leaf::Bool
end

struct PSRSampling <: SamplingScheme
    num_samples::Integer
end

abstract type DualityHandler end

struct DefaultDuality <: DualityHandler end

struct ContinuousConicDualityHandler <: DualityHandler end

struct StrengthenedConicDualityHandler <: DualityHandler end

struct LagrangianDualityHandler <: DualityHandler end

struct BanditDualityHandler <: DualityHandler
    handlers::Vector{DualityHandler}
end

abstract type ForwardPassStrategy end

struct DefaultForwardPassStrategy <: ForwardPassStrategy end

struct RevisitingForwardPassStrategy <: ForwardPassStrategy
    period::Integer
end

struct RiskAdjustedForwardPassStrategy <: ForwardPassStrategy end

struct RegularizedForwardPassStrategy <: ForwardPassStrategy
    rho::Real
end

abstract type CutType end

struct SingleCut <: CutType end

struct MultiCut <: CutType end

struct SDDPPolicyTaskDefinition <: PolicyTaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
    duality_handler::DualityHandler
    forward_pass::ForwardPassStrategy
    cut_type::CutType
end

struct SDDPPolicyTaskArtifact <: PolicyTaskArtifact
    policy::SDDP.PolicyGraph
end

struct SDDPSimulationTaskDefinition <: SimulationTaskDefinition
    num_simulated_series::Integer
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
end

struct SDDPSimulationTaskArtifact <: SimulationTaskArtifact
    definition::SDDPSimulationTaskDefinition
    simulations::Vector{Vector{Dict{Symbol,Any}}}
end

struct SDDPEngine <: Engine
    policy::SDDPPolicyTaskDefinition
    simulation::SDDPSimulationTaskDefinition
end

function get_policy_definition(e::Engine)::PolicyTaskDefinition end
function get_simulation_definition(e::Engine)::SimulationTaskDefinition end

include("sddp.jl")
include("input.jl")
include("input-validators.jl")

export SDDPEngine,
    __build_engine!,
    build,
    train,
    save_policy,
    load_policy,
    simulate,
    save_simulation,
    get_policy_definition,
    get_simulation_definition

end