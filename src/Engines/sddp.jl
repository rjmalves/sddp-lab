include("sddp/scaling.jl")
include("sddp/input.jl")
include("sddp/input-validators.jl")
include("sddp/solver.jl")
include("sddp/build.jl")
include("sddp/diagnostics.jl")
include("sddp/train.jl")
include("sddp/save_policy.jl")
include("sddp/load_policy.jl")
include("sddp/simulate.jl")
include("sddp/save_simulation.jl")

function get_policy_definition(e::SDDPEngine)::SDDPPolicyTaskDefinition
    return e.policy
end

function get_simulation_definition(e::SDDPEngine)::SDDPSimulationTaskDefinition
    return e.simulation
end

function get_stopping_criteria(convergence::Convergence)::Vector{StoppingCriteria}
    return convergence.stopping_criteria
end