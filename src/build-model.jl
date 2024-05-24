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
        
        __add_hydro!(sp, cfg)
        __add_thermal!(sp, cfg)
        __add_systemic!(sp, cfg)
        __add_inflow!(sp, cfg)
        __add_hydro_balance!(sp, cfg)
        __add_load_balance!(sp, cfg)

        Ω_node = SAA[node]
        SDDP.parameterize(sp, Ω_node) do ω
            return JuMP.fix.(sp[:ω_inflow], ω)
        end

        @stageobjective(sp,
            sum(
                cfg.parque_ute.utes[n].generation_cost * sp[:gt][n] for n in 1:n_utes)
                + cfg.system.deficit_cost * sp[:deficit]
                + sum(cfg.system.deficit_cost * 1.0001 * sp[:slack_ghmin][n] for n in 1:n_uhes)
                + sum(cfg.parque_uhe.uhes[n].spill_penal * sp[:vert][n] for n in 1:n_uhes
            )
        )
    end

    return fun_sp_build
end

function __add_hydro!(sp::JuMP.Model, cfg::ConfigData)

    n_uhes = cfg.parque_uhe.n_uhes

    @variable(sp, 0 <= earm[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].earmax,
        SDDP.State,
        initial_value = cfg.parque_uhe.uhes[n].initial_ear)

    @variables(sp, begin
        0 <= gh[n=1:n_uhes] <= cfg.parque_uhe.uhes[n].ghmax
        slack_ghmin[n=1:n_uhes] >= 0
        vert[n=1:n_uhes] >= 0
    end)

    @constraint(sp, [n = 1:n_uhes], gh[n] + slack_ghmin[n] >= cfg.parque_uhe.uhes[n].ghmin)

    @constraint(sp,
        fim_horizonte[n=1:n_uhes],
        earm[n].out >= cfg.parque_uhe.uhes[n].earmin)

end

function __add_thermal!(sp::JuMP.Model, cfg::ConfigData)
    n_utes = cfg.parque_ute.n_utes
    @variable(sp, cfg.parque_ute.utes[n].gtmin <= gt[n=1:n_utes] <= cfg.parque_ute.utes[n].gtmax)

end

function __add_systemic!(sp::JuMP.Model, cfg::ConfigData)
    @variable(sp, deficit >= 0)
end

function __add_inflow!(sp::JuMP.Model, cfg::ConfigData)
    n_uhes = cfg.parque_uhe.n_uhes

    @variable(sp, ena[1:n_uhes])
    @variable(sp, ω_inflow[1:n_uhes])

    @constraint(sp, inflow_model, ena .== ω_inflow)
end

function __add_hydro_balance!(sp::JuMP.Model, cfg::ConfigData)

    n_uhes = cfg.parque_uhe.n_uhes

    @constraint(sp,
        balanco_hidrico[n=1:n_uhes],
        sp[:earm][n].out == sp[:earm][n].in - sp[:gh][n] - sp[:vert][n] + sp[:ena][n] +
                        sum(sp[:gh][j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name) +
                        sum(sp[:vert][j] for j in 1:n_uhes if cfg.parque_uhe.uhes[j].downstream == cfg.parque_uhe.uhes[n].name)
    )
end

function __add_load_balance!(sp::JuMP.Model, cfg::ConfigData)
    @constraint(sp,
        balanco_energetico,
        sum(sp[:gh]) + sum(sp[:gt]) + sp[:deficit] == cfg.system.demand)       
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
