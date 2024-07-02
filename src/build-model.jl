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

    graph = __build_graph(inputs.files.strategy)

    sp_builder = __generate_subproblem_builder(
        inputs.files.configuration, inputs.files.strategy, inputs.files.uncertainties
    )

    # TODO - support multiple solvers
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = GLPK.Optimizer
    )

    return model
end

function __generate_subproblem_builder(
    cfg::Configuration, strategy::Strategy, uncertainties::Uncertainties
)::Function
    num_buses = length(cfg.buses)
    num_hydros = length(cfg.hydros)
    num_thermals = length(cfg.thermals)
    num_stages = length(strategy.horizon)

    SAA = generate_saa(uncertainties, num_stages)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, cfg)
        add_uncertainties!(m, uncertainties)
        __add_hydro_balance!(m, cfg.hydros)

        # TODO - this will change once we have a proper load representation
        # as an stochastic process
        __add_load_balance!(m, cfg, uncertainties, node)

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[:ω_inflow], ω)
        end

        @stageobjective(
            m,
            sum(cfg.thermals.entities[n].cost * m[:gt][n] for n in 1:num_thermals) +
                sum(
                    cfg.buses.entities[n].deficit_cost * m[:deficit][n] for n in 1:num_buses
                ) +
                sum(
                    cfg.hydros.entities[n].bus[].deficit_cost * 1.0001 * m[:slack_ghmin][n]
                    for n in 1:num_hydros
                ) +
                sum(
                    cfg.hydros.entities[n].spillage_penalty * m[:vert][n] for
                    n in 1:num_hydros
                )
        )
    end

    return fun_sp_build
end

# TODO - this will change
function __add_load_balance!(
    m::JuMP.Model, cfg::Configuration, u::Uncertainties, node::Integer
)
    bus_ids = get_ids(cfg.buses)
    num_buses = length(bus_ids)
    num_hydros = length(cfg.hydros)
    num_thermals = length(cfg.thermals)

    @constraint(
        m,
        balanco_energetico[n = 1:num_buses],
        sum(
            m[:gh][j] for j in 1:num_hydros if cfg.hydros.entities[j].bus_id == bus_ids[n]
        ) +
        sum(
            m[:gt][j] for
            j in 1:num_thermals if cfg.thermals.entities[j].bus_id == bus_ids[n]
        ) +
        m[:deficit][bus_ids[n]] == get_load(bus_ids[n], node, u)
    )
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
