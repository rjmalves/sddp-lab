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
    graph = __build_graph(files)
    sp_builder = __generate_subproblem_builder(files)

    # TODO - support multiple solvers
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = GLPK.Optimizer
    )

    return model
end

function __generate_subproblem_builder(files::Files)::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    num_stages = get_number_of_stages(files)

    SAA = generate_saa(scenarios, num_stages)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios)

        # TODO - this will change once we have a proper load representation
        # as an stochastic process
        __add_load_balance!(m, files, node)

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[:ω_inflow], ω)
        end

        return add_system_objective!(m, system)
    end

    return fun_sp_build
end

# TODO - this will change
function __add_load_balance!(m::JuMP.Model, files::Files, node::Integer)
    hydros_entities = get_hydros_entities(files)
    thermals_entities = get_thermals_entities(files)
    scenarios = get_scenarios(files)
    bus_ids = get_ids(get_buses(files))

    num_buses = length(bus_ids)
    num_hydros = length(hydros_entities)
    num_thermals = length(thermals_entities)

    @constraint(
        m,
        balanco_energetico[n = 1:num_buses],
        sum(m[:gh][j] for j in 1:num_hydros if hydros_entities[j].bus_id == bus_ids[n]) +
        sum(
            m[:gt][j] for j in 1:num_thermals if thermals_entities[j].bus_id == bus_ids[n]
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
function __build_graph(files::Files)
    scenario_graph = get_scenario_graph(files)
    num_stages = get_number_of_stages(files)

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
    model::SDDP.PolicyGraph, files::Files
)::Vector{Vector{Dict{Symbol,Any}}}
    SDDP.add_all_cuts(model)

    number_simulated_series = 300

    num_stages = get_number_of_stages(files)
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
