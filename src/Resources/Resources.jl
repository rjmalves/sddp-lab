module Resources

using ..Core
using ..Utils
using JuMP

import GLPK as GLPKInterface
import Clp as ClpInterface
import HiGHS as HiGHSInterface
import Gurobi as GurobiInterface

# TYPES ------------------------------------------------------------------------

abstract type Solver end

struct CLP <: Solver
    params::Dict{String,Any}
end
struct GLPK <: Solver
    params::Dict{String,Any}
end
struct HiGHS <: Solver
    params::Dict{String,Any}
end
struct Gurobi <: Solver
    params::Dict{String,Any}
end

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