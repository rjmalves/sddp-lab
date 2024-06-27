using SDDP

abstract type Task end
abstract type TaskResult end

"""
run(t::Task)

Runs a task that was required for a given entrypoint.
"""
function run(t::Task...) end

"""
run(t::Task)

Runs a task that was required for a given entrypoint.
"""
function run(t::Task...) end

struct Policy <: Task
    inputs::Inputs
    outputs::Outputs
end
struct PolicyResult <: TaskResult
    policy::SDDP.PolicyGraph
end

function run(t::Policy)::PolicyResult
    # Calls build_model and train_model 
end

struct Simulation <: Task
    inputs::inputs
    outputs::Outputs
end
struct SimulationResult <: TaskResult
    simulations::Vector{Vector{Dict{Symbol,Any}}}
end

function run(t::Simulation, policy::PolicyResult)::SimulationResult
    # Calls simulate_model
end

function read_validate_task!(
    t::String, inputs::Inputs, outputs::Outputs, e::CompositeException
)::Union{Task,Nothing}
    task_obj = nothing
    try
        task_type = getfield(@__MODULE__, Symbol(t))
        task_obj = task_type(inputs, outputs)
    catch
        push!(e, AssertionError("Task kind ($kind) not recognized"))
    end
    return task_obj
end