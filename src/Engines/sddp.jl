function build(::SDDPEngine,
    files::Vector{InputModule},
    optimizer::MOI.AbstractOptimizer)::SDDPModel end

function train(model::SDDPModel,
    definition::SDDPPolciyTaskDefinition)::SDDPPolciyTaskArtifact end

function simulate(model::SDDPModel,
    definition::SDDPSimulationTaskDefinition)::SDDPSimulationTaskArtifact end
