function build(engine::Engine, files::Vector{InputModule}, optimizer)::Model end
function build(engine::Engine, files::Vector{InputModule})::Model end
function train(model::Model, definition::PolicyTaskDefinition)::PolicyTaskArtifact end
function save_policy(artifact::PolicyTaskArtifact, path::String, format::TaskResultsFormat) end
function load_policy(model::Model, path::String, format::TaskResultsFormat) end
function simulate(
    model::Model, definition::SimulationTaskDefinition
)::SimulationTaskArtifact end
function save_simulation(
    artifact::SimulationTaskArtifact,
    path::String,
    format::TaskResultsFormat,
    files::Vector{InputModule},
) end

"""
    diagnose(model, engine) -> Bool

Run numerical diagnostics; returns `false` if training should not proceed.
"""
function diagnose(model::Model, engine::Engine)::Bool end
