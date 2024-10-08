# CLASS InputsArtifact

function get_task_output_path(a::InputsArtifact)::String
    return ""
end

function should_write_results(a::InputsArtifact)::Bool
    return false
end

function save_task(a::InputsArtifact)
    return false
end

# CLASS EchoArtifact -----------------------------------------------------------------------

function get_task_output_path(a::EchoArtifact)::String
    return a.task.results.path
end

function should_write_results(a::EchoArtifact)::Bool
    return a.task.results.save
end

function save_task(a::EchoArtifact)
    # TODO - implement export_json(files)
    return true
end

# CLASS PolicyArtifact -----------------------------------------------------------------------

function get_task_output_path(a::PolicyArtifact)::String
    return a.task.results.path
end

function should_write_results(a::PolicyArtifact)::Bool
    return a.task.results.save
end

function save_task(a::PolicyArtifact)
    cuts = get_model_cuts(a.policy)
    write_model_cuts(cuts)
    # plot_model_cuts(cuts, get_system(a.files))
    return true
end

# CLASS  SimulationArtifact -----------------------------------------------------------------------

function get_task_output_path(a::SimulationArtifact)::String
    return a.task.results.path
end

function should_write_results(a::SimulationArtifact)::Bool
    return a.task.results.save
end

function save_task(a::SimulationArtifact)
    write_simulation_results(a.simulations, get_system(a.files))
    # plot_simulation_results(a.simulations, get_system(a.files))
    return true
end
