using .System
using .Scenarios
using .Algorithm
using .Inputs
using .Tasks

"""
    build_model(cfg, ena_dist)

Gera `SDDP.LinearPolicyGraph` parametrizado de acordo com configuracoes de estudo e ENAs fornecidos

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
  - `ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})`: dicionario de ENAs como retornado por
    `Lab.Reader.read_ena()`
"""
function build_model(files::Files)::SDDP.PolicyGraph
    @info "Compilando modelo"

    graph = __build_graph(files.algorithm)

    sp_builder = __generate_subproblem_builder(
        files.system, files.algorithm, files.scenarios
    )

    # TODO - support multiple solvers
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = GLPK.Optimizer
    )

    return model
end

function __generate_subproblem_builder(
    system::SystemData, algorithm::AlgorithmData, scenarios::ScenariosData
)::Function
    num_buses = length(system.buses)
    num_hydros = length(system.hydros)
    num_thermals = length(system.thermals)
    num_stages = length(algorithm.horizon)

    SAA = generate_saa(scenarios, num_stages)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios)
        __add_hydro_balance!(m, system.hydros)

        # TODO - this will change once we have a proper load representation
        # as an stochastic process
        __add_load_balance!(m, system, scenarios, node)

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[:ω_inflow], ω)
        end

        @stageobjective(
            m,
            sum(system.thermals.entities[n].cost * m[:gt][n] for n in 1:num_thermals) +
                sum(
                    system.buses.entities[n].deficit_cost * m[:deficit][n] for
                    n in 1:num_buses
                ) +
                sum(
                    system.hydros.entities[n].bus[].deficit_cost *
                    1.0001 *
                    m[:slack_ghmin][n] for n in 1:num_hydros
                ) +
                sum(
                    system.hydros.entities[n].spillage_penalty * m[:vert][n] for
                    n in 1:num_hydros
                )
        )
    end

    return fun_sp_build
end

# TODO - this will change
function __add_load_balance!(
    m::JuMP.Model, system::SystemData, scenarios::ScenariosData, node::Integer
)
    bus_ids = get_ids(system.buses)
    num_buses = length(bus_ids)
    num_hydros = length(system.hydros)
    num_thermals = length(system.thermals)

    @constraint(
        m,
        balanco_energetico[n = 1:num_buses],
        sum(
            m[:gh][j] for
            j in 1:num_hydros if system.hydros.entities[j].bus_id == bus_ids[n]
        ) +
        sum(
            m[:gt][j] for
            j in 1:num_thermals if system.thermals.entities[j].bus_id == bus_ids[n]
        ) +
        m[:deficit][bus_ids[n]] == get_load(bus_ids[n], node, scenarios)
    )
end

"""
    __build_graph(cfg)

Gera um `SDDP.Graph` parametrizado de acordo com configuracoes de estudo

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function __build_graph(algorithm::AlgorithmData)
    scenario_graph = algorithm.graph
    num_stages = length(algorithm.horizon)

    return generate_scenario_graph(scenario_graph, num_stages)
end

"""
    train_model(model, cfg)

Wrapper para chamada de `SDDP.train` parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function train_model(model::SDDP.PolicyGraph, task::Policy)
    # Debug subproblema
    # SDDP.write_subproblem_to_file(model[1], "subproblem.lp")
    @info "Calculando política"
    max_iterations = task.convergence.max_iterations
    return SDDP.train(model; iteration_limit = max_iterations)
end

"""
    simulate_model(model, cfg)

Realiza simulacao final parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
"""
function simulate_model(
    model::SDDP.PolicyGraph, algorithm::AlgorithmData
)::Vector{Vector{Dict{Symbol,Any}}}
    SDDP.add_all_cuts(model)

    number_simulated_series = 300

    num_stages = length(algorithm.horizon)
    sampler = SDDP.InSampleMonteCarlo(;
        max_depth = num_stages, terminate_on_dummy_leaf = false
    )
    @info "Realizando simulação"
    return SDDP.simulate(
        model,
        number_simulated_series,
        [:gt, :gh, :earm, :deficit, :vert, :ena];
        sampling_scheme = sampler,
        custom_recorders = Dict{Symbol,Function}(
            :cmo => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_energetico]),
            :vagua => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_hidrico]),
            :custo_total => (sp::JuMP.Model) -> JuMP.objective_value(sp),
        ),
    )
end
