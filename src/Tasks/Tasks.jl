module Tasks

abstract type Task end

abstract type TaskArtifact end

include("policy-validators.jl")
include("policy.jl")

include("simulation-validators.jl")
include("simulation.jl")

end