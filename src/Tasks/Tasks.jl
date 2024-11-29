module Tasks

using ..Core
using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Outputs
using CSV
using JSON
using Parquet: Parquet
using Distributed
using DataFrames
using JuMP
using SDDP: SDDP

# TYPES ------------------------------------------------------------------------

abstract type TaskResultsFormat end

struct AnyFormat <: TaskResultsFormat end

struct CSVFormat <: TaskResultsFormat end

struct ParquetFormat <: TaskResultsFormat end

struct TaskResults
    path::String
    save::Bool
    format::TaskResultsFormat
end

abstract type TaskDefinition end

struct Echo <: TaskDefinition
    results::TaskResults
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

struct Policy <: TaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
    results::TaskResults
end

struct SimulationTaskPolicy
    path::String
    load::Bool
    format::TaskResultsFormat
end

struct Simulation <: TaskDefinition
    num_simulated_series::Integer
    policy::SimulationTaskPolicy
    parallel_scheme::ParallelScheme
    results::TaskResults
end

abstract type TaskArtifact end

struct InputsArtifact <: TaskArtifact
    path::String
    files::Vector{InputModule}
end

struct EchoArtifact <: TaskArtifact
    task::Echo
    files::Vector{InputModule}
end

struct PolicyArtifact <: TaskArtifact
    task::Policy
    policy::SDDP.PolicyGraph
    files::Vector{InputModule}
end

struct SimulationArtifact <: TaskArtifact
    task::Simulation
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    files::Vector{InputModule}
end

struct TasksData <: InputModule
    tasks::Vector{TaskDefinition}
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
generate_stopping_rule(s::StoppingCriteria)

Return the StoppingRule object that is used by the algorithm
to decide if the training should be stopped.
"""
function generate_stopping_rule(s::StoppingCriteria)::SDDP.AbstractStoppingRule end

"""
generate_parallel_scheme(p::ParallelScheme)

Generates an `SDDP.AbstractParallelScheme` object from a `ParallelScheme` object, applying
study-specific configurations.
"""
function generate_parallel_scheme(p::ParallelScheme)::SDDP.AbstractParallelScheme end

"""
generate_risk_measure(m::RiskMeasure)

Generates an `SDDP.AbstractRiskMeasure` object from a `RiskMeasure` object, applying
study-specific configurations.
"""
function generate_risk_measure(m::RiskMeasure)::SDDP.AbstractRiskMeasure end

"""
get_task_output_path(a::TaskArtifact)::String

Return the output path to write the task results
"""
function get_task_output_path(a::TaskArtifact)::String end

"""
should_write_results(t::TaskArtifact)::Bool

Returns true if the task should write its results.
"""
function should_write_results(a::TaskArtifact)::Bool end

"""
get_reader(f::TaskResultsFormat)

Gets the reader function that will import the Table data
from the filesystem.
"""
function get_reader(f::TaskResultsFormat)::Function end

"""
get_writer(f::TaskResultsFormat)

Gets the writer function that will export the Table data
to the filesystem.
"""
function get_writer(f::TaskResultsFormat)::Function end

"""
get_extension(f::TaskResultsFormat)::String

Gets the file extension to be used when exporting the data.
"""
function get_extension(f::TaskResultsFormat)::String end

"""
run(t::TaskDefinition, a::Vector{TaskArtifact})

Runs a task that was required for a given entrypoint.
"""
function run_task(t::TaskDefinition, a::Vector{TaskArtifact})::Union{TaskArtifact,Nothing} end

"""
save(a::TaskArtifact)

Write the task results given an artifact.
"""
function save_task(a::TaskArtifact) end

# INTERNALS ------------------------------------------------------------------------

include("stoppingcriteria-validators.jl")
include("stoppingcriteria.jl")

include("convergence-validators.jl")
include("convergence.jl")

include("parallelscheme-validators.jl")
include("parallelscheme.jl")

include("riskmeasure-validators.jl")
include("riskmeasure.jl")

include("taskresultsformat-validators.jl")
include("taskresultsformat.jl")

include("taskresults-validators.jl")
include("taskresults.jl")

include("simulationtaskpolicy-validators.jl")
include("simulationtaskpolicy.jl")

include("model.jl")

include("taskdefinition-validators.jl")
include("taskdefinition.jl")

include("taskartifact.jl")

include("tasksdata-validators.jl")
include("tasksdata.jl")

export TasksData,
    TaskDefinition,
    TaskArtifact,
    InputsArtifact,
    run_task,
    save_task,
    get_task_output_path,
    get_reader,
    get_writer,
    get_extension,
    should_write_results,
    get_tasks,
    generate_stopping_rule,
    generate_risk_measure,
    generate_parallel_scheme

end