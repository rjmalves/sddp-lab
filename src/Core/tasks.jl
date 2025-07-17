"""
build(engine)

Builds the model as expected by a given engine.
"""
function build(engine::Engine, files::Vector{InputModule}, optimizer::MOI.AbstractOptimizer)::AbstractModel end

"""
train(model)

Trains the model as expected by a given engine.
"""
function train(model::Model, definition::PolicyTaskDefinition)::PolicyTaskArtifact end

"""
simulate(model)

Simulate the model as expected by a given engine.
"""
function simulate(model::Model, definition::SimulationTaskDefinition)::SimulationTaskArtifact end
