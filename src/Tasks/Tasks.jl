module Tasks

using ..Algorithm
using ..Resources
using ..System
using ..Utils
using ..Scenarios
using SDDP: SDDP

abstract type TaskDefinition end

abstract type TaskArtifact end

abstract type StoppingCriteria end

struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::StoppingCriteria
end

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
function run(t::TaskDefinition, a::Vector{TaskArtifact})::Union{TaskArtifact,Nothing} end

"""
save(a::TaskArtifact)

Write the task results given an artifact.
"""
function save(a::TaskArtifact) end

include("stoppingcriteria-validators.jl")
include("stoppingcriteria.jl")

include("convergence-validators.jl")
include("convergence.jl")

include("results-validators.jl")
include("results.jl")

include("taskdefinition-validators.jl")
include("taskdefinition.jl")

include("tasksdata-validators.jl")
include("tasksdata.jl")

export TasksData, TaskDefinition, TaskArtifact, Echo, Policy, Simulation

end