using SDDP: SDDP

using .Core
using .Tasks
using .Outputs

# Container for the inputs

struct InputsArtifact <: TaskArtifact
    files::Vector{InputModule}
end

function get_task_output_path(a::InputsArtifact)::String
    return ""
end

function should_write_results(a::InputsArtifact)::Bool
    return false
end

function save(a::InputsArtifact)
    return false
end

# Runner for all given tasks

function run_tasks!(
    entrypoint::Union{Entrypoint,Nothing}, e::CompositeException
)::Vector{TaskArtifact}
    # Returns empty vector if no entrypoint is given
    entrypoint === nothing && return Vector{TaskArtifact}()

    files = get_files(entrypoint)
    @info files
    @info typeof(files)
    tasks = get_tasks(files)
    artifacts = Vector{TaskArtifact}([InputsArtifact(files)])
    for task in tasks
        a = run(task, artifacts)
        a !== nothing || push!(e, AssertionError("Task $task failed"))
        push!(artifacts, a)
    end
    return artifacts
end

# Writer for the results

function save_results(artifacts::Vector{TaskArtifact})
    for a in artifacts
        basedir = pwd()
        if should_write_results(a)
            path = get_task_output_path(a)
            isdir(path) || mkpath(path)
            cd(path)
            save(a)
            cd(basedir)
        end
    end
end

# Echo --------------------------------------------------------

struct EchoArtifact <: TaskArtifact
    task::Echo
    files::Vector{InputModule}
end

function get_task_output_path(a::EchoArtifact)::String
    return a.task.results.path
end

function should_write_results(a::EchoArtifact)::Bool
    return a.task.results.save
end

function run(t::Echo, a::Vector{TaskArtifact})::Union{EchoArtifact,Nothing}
    input_index = findfirst(x -> isa(x, InputsArtifact), a)
    files = a[input_index].files
    return EchoArtifact(t, files)
end

function save(a::EchoArtifact)
    # TODO - implement export_json(files)
    return true
end

# Policy --------------------------------------------------------

struct PolicyArtifact <: TaskArtifact
    task::Policy
    policy::SDDP.PolicyGraph
    files::Vector{InputModule}
end

function get_task_output_path(a::PolicyArtifact)::String
    return a.task.results.path
end

function should_write_results(a::PolicyArtifact)::Bool
    return a.task.results.save
end

function run(t::Policy, a::Vector{TaskArtifact})::Union{PolicyArtifact,Nothing}
    input_index = findfirst(x -> isa(x, InputsArtifact), a)
    files = a[input_index].files
    model = build_model(files)
    train_model(model, t)
    return PolicyArtifact(t, model, files)
end

function save(a::PolicyArtifact)
    cuts = get_model_cuts(a.policy)
    write_model_cuts(cuts)
    plot_model_cuts(cuts, get_system(a.files))
    return true
end

# Simulation --------------------------------------------------------

struct SimulationArtifact <: TaskArtifact
    task::Simulation
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    files::Vector{InputModule}
end

function get_task_output_path(a::SimulationArtifact)::String
    return a.task.results.path
end

function should_write_results(a::SimulationArtifact)::Bool
    return a.task.results.save
end

function run(t::Simulation, a::Vector{TaskArtifact})::Union{SimulationArtifact,Nothing}
    files_index = findfirst(x -> isa(x, InputsArtifact), a)
    files = a[files_index].files
    policy_index = findfirst(x -> isa(x, PolicyArtifact), a)
    policy = a[policy_index].policy
    sims = simulate_model(policy, files)
    return SimulationArtifact(t, sims, files)
end

function save(a::SimulationArtifact)
    write_simulation_results(a.simulations, get_system(a.files))
    plot_simulation_results(a.simulations, get_system(a.files))
    return true
end