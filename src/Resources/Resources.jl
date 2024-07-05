module Resources

using ..Utils

abstract type Solver end

include("solver-validators.jl")
include("solver.jl")

include("resourcesdata-validators.jl")
include("resourcesdata.jl")

export ResourcesData

end