module SDDPlab

# TODO - remover
using Random, Statistics, Distributions
using JSON, CSV, DataFrames
using SDDP, GLPK
using Logging

include("Core/types.jl")
include("Utils/Utils.jl")
include("StochasticProcess/StochasticProcess.jl")
include("Algorithm/Algorithm.jl")
include("Resources/Resources.jl")
include("System/System.jl")
include("Scenarios/Scenarios.jl")
include("Tasks/Tasks.jl")
include("Inputs/Inputs.jl")
include("Outputs/Outputs.jl")
include("model.jl")
include("tasks.jl")
include("Main.jl")
end
