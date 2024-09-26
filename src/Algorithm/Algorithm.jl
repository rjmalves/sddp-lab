module Algorithm

using JSON
using CSV
using DataFrames
using JuMP
using Graphs
using SDDP: SDDP
using Dates

using ..Core
using ..Utils

import Base: length

# TYPES ------------------------------------------------------------------------

abstract type ScenarioGraph end
abstract type Horizon end

struct RegularScenarioGraph <: ScenarioGraph
    discount_rate::Real
end

struct CyclicScenarioGraph <: ScenarioGraph
    discount_rate::Real
    cycle_length::Integer
    cycle_stage::Integer
    max_depth::Integer
end

struct Stage
    index::Integer
    start_date::DateTime
    end_date::DateTime
end

struct ExplicitHorizon <: Horizon
    stages::Vector{Stage}
end

struct AlgorithmData <: InputModule
    graph::ScenarioGraph
    horizon::Horizon
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
generate_scenario_graph(g::ScenarioGraph)

Generates an `SDDP.Graph` object from a `ScenarioGraph` object, applying
study-specific configurations.
"""
function generate_scenario_graph(g::ScenarioGraph, num_stages::Integer)::SDDP.Graph end

"""
length(h::Horizon)

Evaluates the length of the study horizon, in number of stages.
"""
function length(h::Horizon)::Integer end

# INTERNALS ------------------------------------------------------------------------

include("scenariograph-validators.jl")
include("scenariograph.jl")

include("stage-validators.jl")
include("stage.jl")

include("horizon-validators.jl")
include("horizon.jl")

include("algorithmdata-validators.jl")
include("algorithmdata.jl")

export AlgorithmData,
    Horizon,
    ScenarioGraph,
    get_algorithm,
    get_number_of_stages,
    generate_scenario_graph,
    generate_sampler

end
