"""
    build_model(cfg, ena_dist)

Gera `SDDP.LinearPolicyGraph` parametrizado de acordo com configuracoes de estudo e ENAs fornecidos

# Arguments

 * `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
 * `ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})`: dicionario de ENAs como retornado por
     `Lab.Reader.read_ena()`
"""
function build_model(cfg::ConfigData,
    ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})::SDDP.PolicyGraph

    @info "Compilando modelo"

    graph, stages = __build_graph(cfg)

    #coef_lpp = (cfg.uhe.ghmax - cfg.uhe.ghmin) / (cfg.uhe.earmax)

    sampled_enas = __sample_enas(stages, cfg.initial_month, cfg.scenarios_by_stage,
        cfg.parque_uhe.n_uhes, cfg.cycle_lenght, ena_dist)
    
    sp_builder = __generate_subproblem_builder(cfg, sampled_enas)

    model = SDDP.PolicyGraph(
        sp_builder,
        graph,
        sense=:Min,
        lower_bound=0.0,
        optimizer=GLPK.Optimizer)

    return model

end

function __generate_subproblem_builder(cfg::ConfigData,
    SAA::Vector{Vector{Vector{Float64}}})::Function

    n_uhes = cfg.parque_uhe.n_uhes
    n_utes = cfg.parque_ute.n_utes

    function fun_sp_build(sp::JuMP.Model, node::Int)
        
        # variaveis de estado
        @variable(sp,
            0 <= earm[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].earmax,
            SDDP.State,
            initial_value = cfg.parque_uhe.uhes[n].initial_ear)

        # variaveis de decisao das hidro
        @variables(sp, begin
            0 <= gh[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].ghmax
            slack_ghmin[n=1:n_uhes] >= 0
            vert[n=1:n_uhes] >= 0
            ena[1:n_uhes]
        end)

        # folga de ghmin
        @constraint(sp, [n = 1:n_uhes], gh[n] + slack_ghmin[n] >= cfg.parque_uhe.uhes[n].ghmin)

        # variaveis de decisao das termicas
        @variable(sp, cfg.parque_ute.utes[n].gtmin <= gt[n=1:n_utes] <= cfg.parque_ute.utes[n].gtmax)

        # deficit
        @variable(sp, deficit >= 0)

        # parametrizacao de transicao de estados
        node_enas = SAA[node]
        SDDP.parameterize(sp, node_enas) do w
            return JuMP.fix.(ena, w)
        end

        # Balanco hidrico
        @constraint(sp,
            balanco_hidrico[n=1:n_uhes],
            earm[n].out == earm[n].in - gh[n] - vert[n] + ena[n] +
                           sum(gh[j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name) +
                           sum(vert[j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name)
        )


        # Balanco energetico
        @constraint(sp,
            balanco_energetico,
            sum(gh) + sum(gt) + deficit == cfg.system.demand)

        # LPP
        #@constraint(sp,
        #    lpp,
        #    gh <= coef_lpp * earm.in)

        # Nivel minimo
        @constraint(sp,
            fim_horizonte[n=1:n_uhes],
            earm[n].out >= cfg.parque_uhe.uhes[n].earmin)

        # Custo
        @stageobjective(sp, sum(cfg.parque_ute.utes[n].generation_cost * gt[n] for n in 1:n_utes)
                                    + cfg.system.deficit_cost * deficit
                                    + sum(cfg.system.deficit_cost * 1.0001 * slack_ghmin[n] for n in 1:n_uhes)
                                    + sum(cfg.parque_uhe.uhes[n].spill_penal * vert[n] for n in 1:n_uhes))
    end

    return fun_sp_build
end

"""
    __sample_enas(stages, initial_month, number_of_samples, n_uhes, period, distributions)

Amostra SAA de ENAs a partir de um dicionario de distribuicoes periodicas

# Arguments

 * `stages::Int`: numero de estágios para construção do SAA
 * `initial_month::Int`: mes inicial
 * `number_of_samples::Int`: numero de aberturas a cada estagio
 * `n_uhes::Int`: numero de UHEs
 * `period::Int`: tamanho do ciclo
 * `distributions::Dict{Int,Vector{Float64}}`: dicionario contendo meida e sd por UHE por mes, como
     retornado por `Lab.Reader.read_ena()`
"""
function __sample_enas(stages::Int, initial_month::Int, number_of_samples::Int,
    n_uhes::Int,period::Int,
    distributions::Dict{Int,Dict{Int,Vector{Float64}}})::Vector{Vector{Vector{Float64}}}

    Random.seed!(0)

    # para cada estagio, um vetor tamanho number_of_samples cujos elementos sao realizacoes
    # n_uhe-dimensional
    out = [[zeros(n_uhes) for u in 1:number_of_samples] for s in 1:stages]
    for u in 1:n_uhes
        for s in 1:stages
            params = distributions[u][(s+initial_month-1)%period+1]
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

 * `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function __build_graph(cfg::ConfigData)
    graph = SDDP.Graph(0)
    edge_prob = cfg.discout_by_stage ? cfg.discout_factor : 1.0

    if cfg.cyclic
        if cfg.discout_by_cycle
            edge_prob = cfg.discout_factor ^ (1/cfg.cycle_lenght)
        end
        for s in 1:cfg.cycle_lenght
            SDDP.add_node(graph, s)
            SDDP.add_edge(graph, s-1 => s, edge_prob)
        end
        SDDP.add_edge(graph, cfg.cycle_lenght => 1, edge_prob)
        return graph, cfg.cycle_lenght
    else
        nstages = Int(cfg.cycle_lenght * cfg.cycles)
        for s in 1:nstages
            SDDP.add_node(graph, s)
            SDDP.add_edge(graph, s-1 => s, edge_prob)
        end
        return graph, nstages
    end
end
