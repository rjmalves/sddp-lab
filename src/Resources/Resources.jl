module Resources

using ..Utils

abstract type Solver end

include("solver-validators.jl")
include("solver.jl")

include("environment-validators.jl")
include("environment.jl")

end