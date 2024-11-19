
"""
    build_model(cfg, ena_dist)

Gera `SDDP.LinearPolicyGraph` parametrizado de acordo com configuracoes de estudo e ENAs fornecidos

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
  - `ena_dist::Dict{Int64,Dict{Int64,Vector{Float64}}})`: dicionario de ENAs como retornado por
    `Lab.Reader.read_ena()`
"""
function __build_model(files::Vector{InputModule})::SDDP.PolicyGraph
    @info "Compiling model"
    graph = __build_graph(files)
    sp_builder = __generate_subproblem_builder(files)
    optimizer = generate_optimizer(get_resources(files))
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = optimizer
    )

    return model
end

function __generate_subproblem_builder(files::Vector{InputModule})::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    num_stages = get_number_of_stages(get_algorithm(files))

    set_seed!(scenarios)

    SAA = generate_saa(scenarios, num_stages)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios)

        # TODO - this will change once we have a proper load representation
        # as an stochastic process
        __add_load_balance!(m, files, node)

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[ω_INFLOW], ω)
        end

        add_system_objective!(m, system)

        return nothing
    end

    return fun_sp_build
end

# TODO - this will change
function __add_load_balance!(m::JuMP.Model, files::Vector{InputModule}, node::Integer)
    system = get_system(files)
    hydros_entities = get_hydros_entities(system)
    thermals_entities = get_thermals_entities(system)
    lines_entities = get_lines_entities(system)
    scenarios = get_scenarios(files)
    bus_ids = get_ids(get_buses(system))

    num_buses = length(bus_ids)
    num_lines = length(lines_entities)
    num_hydros = length(hydros_entities)
    num_thermals = length(thermals_entities)

    m[LOAD_BALANCE] = @constraint(
        m,
        [n = 1:num_buses],
        sum(
            m[HYDRO_GENERATION][j] for
            j in 1:num_hydros if hydros_entities[j].bus_id == bus_ids[n]
        ) +
        sum(
            m[THERMAL_GENERATION][j] for
            j in 1:num_thermals if thermals_entities[j].bus_id == bus_ids[n]
        ) +
        sum(
            m[DIRECT_EXCHANGE][j] - m[REVERSE_EXCHANGE][j] for
            j in 1:num_lines if lines_entities[j].target_bus_id == bus_ids[n]
        ) +
        sum(
            m[REVERSE_EXCHANGE][j] - m[DIRECT_EXCHANGE][j] for
            j in 1:num_lines if lines_entities[j].source_bus_id == bus_ids[n]
        ) +
        m[DEFICIT][bus_ids[n]] == get_load(bus_ids[n], node, scenarios)
    )
    return nothing
end

"""
    __build_graph(cfg)

Gera um `SDDP.Graph` parametrizado de acordo com configuracoes de estudo

# Arguments

  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function __build_graph(files::Vector{InputModule})
    return generate_scenario_graph(get_algorithm(files))
end

"""
    train_model(model, cfg)

Wrapper para chamada de `SDDP.train` parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function __train_model(
    model::SDDP.PolicyGraph,
    convergence::Convergence,
    risk::RiskMeasure,
    parallel::ParallelScheme,
)
    # Debug subproblema
    # SDDP.write_subproblem_to_file(model[1], "subproblem.lp")
    @info "Evaluating policy"
    max_iterations = convergence.max_iterations
    stopping_rule = generate_stopping_rule(get_stopping_criteria(convergence))
    risk_measure = generate_risk_measure(risk)
    parallel_scheme = generate_parallel_scheme(parallel)
    return SDDP.train(
        model;
        iteration_limit = max_iterations,
        stopping_rules = [stopping_rule],
        risk_measure = risk_measure,
        parallel_scheme = parallel_scheme,
    )
end

function __add_cuts_from_stage!(
    cutdata::Vector{Dict{String,Any}}, cuts::DataFrame, node::Int64
)
    stage_cuts = filter(row -> row["stage"] == node, cuts)
    cut_indexes = Int64.(unique(stage_cuts[!, "cut_index"]))
    nodedata = Dict{String,Any}(
        "risk_set_cuts" => [], "node" => string(node), "multi_cuts" => []
    )
    single_cuts = Dict{String,Any}[]
    for cut_index in cut_indexes
        cut_rows = filter(row -> row["cut_index"] == cut_index, stage_cuts)
        intercept = 0.0
        states = Dict{String,Float64}()
        coefficients = Dict{String,Float64}()
        for cut_coef in eachrow(cut_rows)
            if (cut_coef["state_variable_name"] == POLICY_CUTS_OUTPUT_INTERCEPT_NAME)
                intercept += cut_coef["state"]
            else
                key = "$(cut_coef["state_variable_name"])[$(cut_coef["state_variable_id"])]"
                state_value = cut_coef["state"]
                coefficient_value = cut_coef["coefficient"]
                push!(states, key => state_value)
                push!(coefficients, key => coefficient_value)
            end
        end
        push!(
            single_cuts,
            Dict{String,Any}(
                "state" => states, "intercept" => intercept, "coefficients" => coefficients
            ),
        )
    end
    nodedata["single_cuts"] = single_cuts
    return push!(cutdata, nodedata)
end

function __load_external_cuts!(model::SDDP.PolicyGraph, cuts::DataFrame)
    jsondata = Dict{String,Any}[]
    stages = Int64.(unique(cuts[!, "stage"]))
    for stage in stages
        __add_cuts_from_stage!(jsondata, cuts, stage)
    end
    # Adds for the last node
    __add_cuts_from_stage!(jsondata, cuts, maximum(stages) + 1)
    # Writes and reads json
    jsonpath = joinpath(tempdir(), "rawcuts2.json")
    open(jsonpath, "w") do f
        JSON.print(f, jsondata)
    end
    return SDDP.read_cuts_from_file(model, jsonpath)
end

"""
    simulate_model(model, cfg)

Realiza simulacao final parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
"""
function __simulate_model(
    model::SDDP.PolicyGraph,
    files::Vector{InputModule},
    number_simulated_series::Integer,
    parallel::ParallelScheme,
)::Vector{Vector{Dict{Symbol,Any}}}
    SDDP.add_all_cuts(model)
    sampler = generate_sampler(get_algorithm(files))
    parallel_scheme = generate_parallel_scheme(parallel)
    @info "Running simulation"
    simulation_result = SDDP.simulate(
        model,
        number_simulated_series,
        [
            THERMAL_GENERATION,
            THERMAL_GENERATION_COST,
            INFLOW,
            TURBINED_FLOW,
            SPILLAGE,
            OUTFLOW,
            HYDRO_GENERATION,
            STORED_VOLUME,
            DEFICIT,
            NET_EXCHANGE,
        ];
        sampling_scheme = sampler,
        custom_recorders = Dict{Symbol,Function}(
            MARGINAL_COST => (sp::JuMP.Model) -> JuMP.dual.(sp[LOAD_BALANCE]),
            WATER_VALUE => (sp::JuMP.Model) -> JuMP.dual.(sp[HYDRO_BALANCE]),
            TOTAL_COST => (sp::JuMP.Model) -> JuMP.objective_value(sp),
        ),
        parallel_scheme = parallel_scheme,
    )
    return simulation_result
end
