module Resources

using ..Core
using ..Utils

# TYPES ------------------------------------------------------------------------

abstract type Solver end

struct CLP <: Solver end
struct GLPK <: Solver end

# GENERAL METHODS ------------------------------------------------------------------------

# INTERNALS ------------------------------------------------------------------------

include("solver-validators.jl")
include("solver.jl")

include("resourcesdata-validators.jl")
include("resourcesdata.jl")

export ResourcesData, get_resources

end