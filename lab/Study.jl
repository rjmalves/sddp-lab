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
            for s in 0:stages-1
    ]
end

function __sample_enas(stages::Int, initial_month::Int, number_of_samples::Int,
    n_uhes::Int,
    distributions::Dict{Int,Dict{Int,Vector{Float64}}})::Vector{Vector{Vector{Float64}}}

    # para cada estagio, um vetor tamanho number_of_samples cujos elementos sao realizacoes 
    # n_uhe-dimensional
    out = [[zeros(n_uhes) for u in 1:number_of_samples] for s in 1:stages]
    for u in 1:n_uhes
        for s in 1:stages
            dist = Normal(distributions[u][(s+initial_month-1)%12+1][1],
                distributions[u][(s+initial_month-1)%12+1][2])
            dist = truncated(dist, 0.0, Inf)
            for n in 1:number_of_samples
                out[s][n][u] += rand(dist, 1)[1]
            end
        end
    end

    return out

end

function build_model(cfg::ConfigData,
    ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})::SDDP.PolicyGraph

    @info "Compilando modelo"
    stages = Int(12 * cfg.years)
    n_uhes = cfg.parque_uhe.n_uhes

    graph = SDDP.LinearGraph(stages)
    # SDDP.add_edge(graph, stages => 1, 0.95)

    #coef_lpp = (cfg.uhe.ghmax - cfg.uhe.ghmin) / (cfg.uhe.earmax)

    sampled_enas = __sample_enas(stages, cfg.initial_month, cfg.scenarios_by_stage,
        n_uhes, ena_dist)

    model = SDDP.PolicyGraph(graph,
        sense=:Min,
        lower_bound=0.0,
        optimizer=GLPK.Optimizer) do subproblem, node

        # variaveis de estado
        @variable(subproblem,
            0 <= earm[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].earmax,
            SDDP.State,
            initial_value = cfg.parque_uhe.uhes[n].initial_ear)

        # variaveis de decisao das hidro
        @variables(subproblem, begin
            0 <= gh[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].ghmax
            slack_ghmin[n=1:n_uhes] >= 0
            vert[n=1:n_uhes] >= 0
            ena[1:n_uhes]
        end)

        # folga de ghmin
        @constraint(subproblem, [n = 1:n_uhes], gh[n] + slack_ghmin[n] >= cfg.parque_uhe.uhes[n].ghmin)

        # variaveis de decisao das termicas
        @variable(subproblem, cfg.ute.gtmin <= gt <= cfg.ute.gtmax)

        # deficit
        @variable(subproblem, deficit >= 0)

        # parametrizacao de transicao de estados
        node_enas = sampled_enas[node]
        SDDP.parameterize(subproblem, node_enas) do w
            return JuMP.fix.(ena, w)
        end

        # Balanco hidrico
        @constraint(subproblem,
            balanco_hidrico[n=1:n_uhes],
            earm[n].out == earm[n].in - gh[n] - vert[n] + ena[n] +
                           sum(gh[j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name) +
                           sum(vert[j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name)
        )


        # Balanco energetico
        @constraint(subproblem,
            balanco_energetico,
            sum(gh) + gt + deficit == cfg.system.demand)

        # LPP 
        #@constraint(subproblem,
        #    lpp,
        #    gh <= coef_lpp * earm.in)

        # Nivel minimo
        @constraint(subproblem,
            fim_horizonte[n=1:n_uhes],
            earm[n].out >= cfg.parque_uhe.uhes[n].earmin)

        # Custo
        @stageobjective(subproblem, cfg.ute.generation_cost * gt
                                    + cfg.system.deficit_cost * deficit
                                    + sum(cfg.system.deficit_cost * 1.0001 * slack_ghmin[n] for n in 1:n_uhes)
                                    + sum(cfg.parque_uhe.uhes[n].spill_penal * vert[n] for n in 1:n_uhes))
    end

    return model

end

function train_model(model::SDDP.PolicyGraph,
    cfg::ConfigData)
    # Debug subproblema
    # SDDP.write_subproblem_to_file(model[1], "subproblem.lp")
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
        [:gt, :gh, :earm, :deficit, :vert, :ena],
        custom_recorders=Dict{Symbol,Function}(
            :cmo => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_energetico]),
            :vagua => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_hidrico]),
        ),)
end

end