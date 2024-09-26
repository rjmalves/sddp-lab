module Resources

using ..Core
using ..Utils

# TYPES ------------------------------------------------------------------------

abstract type Solver end

struct CLP <: Solver end
struct GLPK <: Solver end
struct HiGHS <: Solver end

# GENERAL METHODS ------------------------------------------------------------------------

"""
generate_optimizer(s::Solver)

Return the optimizer object that is used by the optimization engine.
"""
function generate_optimizer(s::Solver) end

# INTERNALS ------------------------------------------------------------------------

include("solver-validators.jl")
include("solver.jl")

include("resourcesdata-validators.jl")
include("resourcesdata.jl")

export ResourcesData, get_resources, generate_optimizer

end