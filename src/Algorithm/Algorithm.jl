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

abstract type ScenarioGraph end
abstract type Horizon end
abstract type RiskMeasure end

struct Stage
    index::Integer
    start_date::DateTime
    end_date::DateTime
end

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

"""
generate_risk_measure(m::RiskMeasure)

Generates an `SDDP.AbstractRiskMeasure` object from a `RiskMeasure` object, applying
study-specific configurations.
"""
function generate_risk_measure(m::RiskMeasure)::SDDP.AbstractRiskMeasure end

include("scenariograph-validators.jl")
include("scenariograph.jl")

include("stage-validators.jl")
include("stage.jl")

include("horizon-validators.jl")
include("horizon.jl")

include("riskmeasure-validators.jl")
include("riskmeasure.jl")

include("algorithmdata-validators.jl")
include("algorithmdata.jl")

export AlgorithmData, Horizon, ScenarioGraph, generate_scenario_graph

end
