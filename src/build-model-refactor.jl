"""
    build_model(cfg, ena_dist)

Gera `SDDP.LinearPolicyGraph` parametrizado de acordo com configuracoes de estudo e ENAs fornecidos

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
  - `ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})`: dicionario de ENAs como retornado por
    `Lab.Reader.read_ena()`
"""
function build_model(inputs::Inputs)::SDDP.PolicyGraph
    @info "Compilando modelo"

    graph = __build_graph(inputs.strategy)

    # sampled_enas = __sample_enas(
    #     stages,
    #     cfg.initial_month,
    #     cfg.scenarios_by_stage,
    #     cfg.parque_uhe.n_uhes,
    #     cfg.cycle_lenght,
    #     ena_dist,
    # )

    # TODO - read SAA from scenarios
    SAA = nothing

    sp_builder = __generate_subproblem_builder(cfg, sampled_enas)

    # TODO - support multiple solvers
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = GLPK.Optimizer
    )

    return model
end

function __generate_subproblem_builder(
    cfg::Configuration, SAA::Vector{Vector{Vector{Float64}}}
)::Function
    num_hydros = length(cfg.hydros)
    num_thermals = length(cfg.thermals)

    function fun_sp_build(m::JuMP.Model, node::Int)
        add_system_elements!(m, cfg)
        __add_inflow!(m, cfg)
        __add_hydro_balance!(m, cfg)
        __add_load_balance!(m, cfg)

        Ω_node = SAA[node]
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[:ω_inflow], ω)
        end

        # TODO - modify when load balance by bus is implemented
        deficit_cost = cfg.buses.entities[1].deficit_cost

        @stageobjective(
            m,
            sum(
                    cfg.thermals.entities[n].generation_cost * m[:gt][n] for
                    n in 1:num_thermals
                ) +
                deficit_cost * m[:deficit] +
                sum(deficit_cost * 1.0001 * m[:slack_ghmin][n] for n in 1:num_hydros) +
                sum(
                    cfg.hydros.entities[n].spillage_penalty * m[:vert][n] for
                    n in 1:num_hydros
                )
        )
    end

    return fun_sp_build
end

function __add_inflow!(m::JuMP.Model, hydros::Hydros)
    num_hydros = length(hydros)

    @variable(m, ena[1:num_hydros])
    @variable(m, ω_inflow[1:num_hydros])

    @constraint(m, inflow_model, ena .== ω_inflow)
end

function __add_hydro_balance!(m::JuMP.Model, hydros::Hydros)
    num_hydros = length(cfg.hydros)

    @constraint(
        m,
        balanco_hidrico[n = 1:num_hydros],
        m[:earm][n].out ==
            m[:earm][n].in - m[:gh][n] - m[:vert][n] +
        m[:ena][n] +
        sum(
            m[:gh][j] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
        ) +
        sum(
            m[:vert][j] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
        )
    )
end

# TODO - read load from scenarios
function __add_load_balance!(m::JuMP.Model, cfg::Configuration)
    @constraint(m, balanco_energetico, sum(m[:gh]) + sum(m[:gt]) + m[:deficit] == 50.0)
end

"""
    __sample_enas(stages, initial_month, number_of_samples, n_uhes, period, distributions)

Amostra SAA de ENAs a partir de um dicionario de distribuicoes periodicas

# Arguments

  - `stages::Int`: numero de estágios para construção do SAA
  - `initial_month::Int`: mes inicial
  - `number_of_samples::Int`: numero de aberturas a cada estagio
  - `n_uhes::Int`: numero de UHEs
  - `period::Int`: tamanho do ciclo
  - `distributions::Dict{Int,Vector{Float64}}`: dicionario contendo meida e sd por UHE por mes, como
    retornado por `Lab.Reader.read_ena()`
"""
function __sample_enas(
    stages::Int,
    initial_month::Int,
    number_of_samples::Int,
    n_uhes::Int,
    period::Int,
    distributions::Dict{Int,Dict{Int,Vector{Float64}}},
)::Vector{Vector{Vector{Float64}}}
    Random.seed!(0)

    # para cada estagio, um vetor tamanho number_of_samples cujos elementos sao realizacoes
    # n_uhe-dimensional
    out = [[zeros(n_uhes) for u in 1:number_of_samples] for s in 1:stages]
    for u in 1:n_uhes
        for s in 1:stages
            params = distributions[u][(s + initial_month - 1) % period + 1]
            dist = Normal(params[1], params[2])
            dist = truncated(dist, 0.0, Inf)
            for n in 1:number_of_samples
                out[s][n][u] += rand(dist, 1)[1]
            end
        end
    end

    return out
end

"""
    __build_graph(cfg)

Gera um `SDDP.Graph` parametrizado de acordo com configuracoes de estudo

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function __build_graph(strategy::Strategy)
    scenario_graph = strategy.graph
    num_stages = length(strategy.horizon)

    return generate_scenario_graph(scenario_graph, num_stages)
end
