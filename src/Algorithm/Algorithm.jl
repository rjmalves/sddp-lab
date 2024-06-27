module Algorithm

using JSON
using CSV
using DataFrames
using JuMP
using Graphs
using SDDP
using Dates

using ..Utils

import Base: length

abstract type ScenarioGraph end
abstract type Horizon end
abstract type RiskMeasure end
abstract type StoppingCriteria end

struct Stage
    index::Integer
    start_date::DateTime
    end_date::DateTime
end

struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::StoppingCriteria
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

"""
generate_stopping_rules(m::RiskMeasure)

Generates an `SDDP.AbstractStoppingRule` object from a `Convergence` object, applying
study-specific configurations.
"""
function generate_stopping_rules(c::Convergence)::SDDP.AbstractStoppingRule end

include("scenariograph-validators.jl")
include("scenariograph.jl")

include("stage-validators.jl")
include("stage.jl")

include("horizon-validators.jl")
include("horizon.jl")

include("riskmeasure-validators.jl")
include("riskmeasure.jl")

include("stoppingcriteria-validators.jl")
include("stoppingcriteria.jl")

include("convergence-validators.jl")
include("convergence.jl")

include("strategy-validators.jl")
include("strategy.jl")

export Strategy, generate_scenario_graph

end
