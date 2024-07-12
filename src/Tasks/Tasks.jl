module Tasks

using ..Core
using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using ..Outputs
using JuMP
using GLPK
using SDDP: SDDP

# TYPES ------------------------------------------------------------------------

struct Results
    path::String
    save::Bool
end

abstract type TaskDefinition end

struct Echo <: TaskDefinition
    results::Results
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

struct Policy <: TaskDefinition
    convergence::Convergence
    results::Results
end

struct Simulation <: TaskDefinition
    num_simulated_series::Integer
    policy_path::String
    results::Results
end

abstract type TaskArtifact end

struct InputsArtifact <: TaskArtifact
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
function generate_stopping_rule(s::StoppingCriteria) end

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

include("results-validators.jl")
include("results.jl")

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
    should_write_results,
    get_tasks,
    generate_stopping_rule

end