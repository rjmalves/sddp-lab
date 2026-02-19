module Engines

using ..Lab
using ..StochasticProcess
using ..Scenarios
using ..System
using ..Utils

using Dates
using DataFrames
using Distributed
using Statistics: Statistics
using SDDP: SDDP
using JuMP: JuMP
using JSON
using CSV
import MathOptInterface as MOI

struct ScalingConfig
    factors::Dict{Symbol,Float64}
end

struct SDDPModel <: Model
    policy_graph::SDDP.PolicyGraph
    scaling::ScalingConfig
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

struct Threaded <: ParallelScheme end

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

abstract type ScalingMode end

struct NoScaling <: ScalingMode end

struct AutoScaling <: ScalingMode end

struct TrainingLogConfig
    log_file::String
    log_frequency::Int
    log_every_iteration::Bool
    print_level::Int
end

struct TrainingLogEntry
    iteration::Int
    bound::Float64
    simulation_value::Float64
    time::Float64
    total_solves::Int
    serious_numerical_issue::Bool
end

struct TrainingLog
    status::Symbol
    iterations::Vector{TrainingLogEntry}
end

struct SDDPPolicyTaskDefinition <: PolicyTaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
    duality_handler::DualityHandler
    forward_pass::ForwardPassStrategy
    cut_type::CutType
    scaling::ScalingMode
    logging::TrainingLogConfig
end

struct SDDPPolicyTaskArtifact <: PolicyTaskArtifact
    policy::SDDP.PolicyGraph
    training_log::Union{TrainingLog,Nothing}
end

struct SDDPSimulationTaskDefinition <: SimulationTaskDefinition
    num_simulated_series::Integer
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
end

struct SDDPSimulationTaskArtifact <: SimulationTaskArtifact
    definition::SDDPSimulationTaskDefinition
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    scaling::ScalingConfig
end

struct DiagnosticsConfig
    run_numerical_report::Bool
    warn_threshold::Float64
    halt_threshold::Float64
end

struct SolverConfig
    solver_name::String
    attributes::Dict{String,Any}
end

abstract type InflowNonNegativity end

struct InflowNone <: InflowNonNegativity end

struct InflowPenalty <: InflowNonNegativity
    penalty_cost::Float64
end

struct InflowTruncation <: InflowNonNegativity end

struct InflowTruncationWithPenalty <: InflowNonNegativity
    penalty_cost::Float64
end

struct OutOfSampleValidation
    num_simulations::Integer
    seed::Integer
    branchings::Integer
    parallel_scheme::ParallelScheme
end

struct SDDPValidationTaskArtifact
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    scaling::ScalingConfig
    statistics::Dict{String,Float64}
end

struct DebugConfig
    write_subproblems::Bool
    subproblem_nodes::Vector{Any}
    subproblem_format::String
    deterministic_equivalent::Bool
    det_equiv_time_limit::Float64
end

struct SDDPEngine <: Engine
    policy::SDDPPolicyTaskDefinition
    simulation::SDDPSimulationTaskDefinition
    diagnostics::DiagnosticsConfig
    solver::SolverConfig
    inflow_non_negativity::InflowNonNegativity
    validation::Union{OutOfSampleValidation,Nothing}
    debug::DebugConfig
end

function get_policy_definition(e::Engine)::PolicyTaskDefinition end
function get_simulation_definition(e::Engine)::SimulationTaskDefinition end

include("sddp.jl")
include("input.jl")
include("input-validators.jl")

export SDDPEngine,
    DiagnosticsConfig,
    SolverConfig,
    TrainingLogConfig,
    TrainingLogEntry,
    TrainingLog,
    InflowNonNegativity,
    InflowNone,
    InflowPenalty,
    InflowTruncation,
    InflowTruncationWithPenalty,
    OutOfSampleValidation,
    SDDPValidationTaskArtifact,
    DebugConfig,
    __build_engine!,
    build,
    train,
    save_policy,
    load_policy,
    simulate,
    save_simulation,
    validate,
    save_validation,
    debug,
    get_policy_definition,
    get_simulation_definition,
    get_validation_definition,
    create_optimizer,
    ScalingConfig,
    NoScaling,
    AutoScaling,
    Threaded

end