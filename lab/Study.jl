module Study

using Statistics
using Distributions
using Logging
using Random
using SDDP
using GLPK

export build_model, train_model, simulate_model

using ..Config: ConfigData
using ..Reader: read_config, read_ena
using ..Writer: plot_simulation_results, write_simulation_results

function __sample_enas(stages::Int,
    initial_month::Int,
    number_of_samples::Int,
    distributions::Dict{Int,Vector{Float64}})::Vector{Vector{Float64}}
    return [rand(truncated(Normal(distributions[(s+initial_month-1)%12+1][1],
                distributions[(s+initial_month-1)%12+1][2]),
            0.0,
            Inf),
        number_of_samples)
            for s in 1:stages
    ]
end

function build_model(cfg::ConfigData,
    ena_dist::Dict{Int64,Vector{Float64}})::SDDP.PolicyGraph

    @info "Compilando modelo"
    stages = Int(12 * cfg.years)
    sampled_enas = __sample_enas(stages, cfg.initial_month, cfg.scenarios_by_stage, ena_dist)

    model = SDDP.LinearPolicyGraph(stages=stages,
        sense=:Min,
        lower_bound=0.0,
        optimizer=GLPK.Optimizer) do subproblem, node
        @variable(subproblem,
            0 <= earm <= cfg.uhe.earmax,
            SDDP.State,
            initial_value = cfg.uhe.initial_ear)
        @variables(subproblem, begin
            cfg.ute.gtmin <= gt <= cfg.ute.gtmax
            cfg.uhe.ghmin <= gh <= cfg.uhe.ghmax
            vert >= 0
            deficit >= 0
            ena
        end)

        node_enas = sampled_enas[node]

        SDDP.parameterize(subproblem, node_enas) do w
            return JuMP.fix(ena, w)
        end

        # Balanço hídrico
        @constraint(subproblem,
            earm.out == earm.in - gh - vert + ena)
        # Balanço energético
        @constraint(subproblem,
            gh + gt + deficit == cfg.system.demand)
        # Custo
        @stageobjective(subproblem, cfg.ute.generation_cost * gt
                                    + cfg.system.deficit_cost * deficit
                                    + cfg.uhe.spill_penal * vert)
    end

    return model

end

function train_model(model::SDDP.PolicyGraph,
    cfg::ConfigData)
    @info "Calculando política"
    SDDP.train(model,
        iteration_limit=cfg.max_iterations,
    )
end


function simulate_model(model::SDDP.PolicyGraph,
    cfg::ConfigData)::Vector{Vector{Dict{Symbol,Any}}}
    SDDP.add_all_cuts(model)
    @info "Realizando simulação"
    return SDDP.simulate(model,
        cfg.number_simulated_series,
        [:gt, :gh, :earm, :deficit, :vert, :ena])
end

end