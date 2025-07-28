"""
build(engine, files, optimizer)

Builds the model as expected by a given engine.
"""
function build(engine::Engine, files::Vector{InputModule}, optimizer)::Model end

"""
train(model, definition)

Trains the model as expected by a given engine.
"""
function train(model::Model, definition::PolicyTaskDefinition)::PolicyTaskArtifact end

"""
save_policy(artifact, path, format)

Saves a trained policy to the filesystem as expected by a given engine.
"""
function save_policy(artifact::PolicyTaskArtifact, path::String, format::TaskResultsFormat) end

"""
load_policy(model, path, format)

Loads a trained policy from the filesystem as expected by a given engine.
"""
function load_policy(model::Model, path::String, format::TaskResultsFormat) end

"""
simulate(model, definition)

Simulate the model as expected by a given engine.
"""
function simulate(
    model::Model, definition::SimulationTaskDefinition
)::SimulationTaskArtifact end

"""
save_simulation(artifact, path, format)

Saves a simulation to the filesystem as expected by a given engine.
"""
function save_simulation(
    artifact::SimulationTaskArtifact,
    path::String,
    format::TaskResultsFormat,
    files::Vector{InputModule},
) end
