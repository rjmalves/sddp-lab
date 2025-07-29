function Lab.build(::SDDPEngine, files::Vector{InputModule}, optimizer)::SDDPModel
    @info "Compiling model"
    graph = __build_graph(files)
    sp_builder = __generate_subproblem_builder(files)
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = optimizer
    )

    return SDDPModel(model)
end

# SYSTEM ELEMENT METHODS ----------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, ses::Buses)
    num_buses = length(ses)

    # Adds variables registering internal names by symbols
    m[LOAD] = JuMP.@variable(m, [1:num_buses], base_name = String(LOAD))
    m[DEFICIT] = JuMP.@variable(m, [1:num_buses], base_name = String(DEFICIT))

    JuMP.set_lower_bound.(m[DEFICIT], 0)

    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::Lines)
    num_lines = length(ses)

    m[DIRECT_EXCHANGE] = JuMP.@variable(
        m, [n = 1:num_lines], base_name = String(DIRECT_EXCHANGE)
    )
    for n in 1:num_lines
        JuMP.set_lower_bound(m[DIRECT_EXCHANGE][n], 0)
        JuMP.set_upper_bound(m[DIRECT_EXCHANGE][n], ses.entities[n].capacity)
    end
    
    m[REVERSE_EXCHANGE] = JuMP.@variable(
        m, [n = 1:num_lines], base_name = String(REVERSE_EXCHANGE)
    )
    for n in 1:num_lines
        JuMP.set_lower_bound(m[REVERSE_EXCHANGE][n], 0)
        JuMP.set_upper_bound(m[REVERSE_EXCHANGE][n], ses.entities[n].capacity)
    end
        
    m[NET_EXCHANGE] = JuMP.@expression(m, m[DIRECT_EXCHANGE] - m[REVERSE_EXCHANGE])
end

function add_system_elements!(m::JuMP.Model, ses::Thermals)
    num_thermals = length(ses)
    m[THERMAL_GENERATION] = JuMP.@variable(
        m, [n = 1:num_thermals], base_name = String(THERMAL_GENERATION)
    )
    for n in 1:num_thermals
        JuMP.set_lower_bound(m[THERMAL_GENERATION][n], ses.entities[n].min_generation)
        JuMP.set_upper_bound(m[THERMAL_GENERATION][n], ses.entities[n].max_generation)
    end

    m[THERMAL_GENERATION_COST] = JuMP.@expression(
        m, [n = 1:num_thermals], ses.entities[n].cost * m[THERMAL_GENERATION][n]
    )

    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::Hydros)
    num_hydros = length(ses)

    m[STORED_VOLUME] = JuMP.@variable(
        m,
        [n = 1:num_hydros],
        base_name = String(STORED_VOLUME),
        SDDP.State,
        initial_value = ses.entities[n].initial_storage
    )

    for n in 1:num_hydros
        # no bounds are set on the 'in' field because this variable is always internally fixed
        # to the previous' stage 'out' with JuMP.fix; this throws an error when the variable being
        # fixed is bounded
        # Indeed, even when a state variable is created the canonical way
        # (using JuMP.@variable(..., SDDP.State)), only the 'out' half receives the bound information
        JuMP.set_lower_bound(m[STORED_VOLUME][n].out, ses.entities[n].min_storage)
        JuMP.set_upper_bound(m[STORED_VOLUME][n].out, ses.entities[n].max_storage)
    end

    m[INFLOW] = JuMP.@variable(m, [1:num_hydros], base_name = String(INFLOW))

    m[TURBINED_FLOW] = JuMP.@variable(m, [1:num_hydros], base_name = String(TURBINED_FLOW))
    JuMP.set_lower_bound.(
        m[TURBINED_FLOW], [e.min_generation / e.productivity for e in ses.entities]
    )
    JuMP.set_upper_bound.(
        m[TURBINED_FLOW], [e.max_generation / e.productivity for e in ses.entities]
    )

    m[SPILLAGE] = JuMP.@variable(m, [n = 1:num_hydros], base_name = String(SPILLAGE))
    JuMP.set_lower_bound.(m[SPILLAGE], 0)

    m[OUTFLOW] = JuMP.@expression(m, m[TURBINED_FLOW] + m[SPILLAGE])

    m[HYDRO_GENERATION] = JuMP.@expression(
        m, [n = 1:num_hydros], ses.entities[n].productivity * m[TURBINED_FLOW][n]
    )

    m[HYDRO_MIN_GENERATION_SLACK] = JuMP.@variable(
        m, [n = 1:num_hydros], base_name = String(HYDRO_MIN_GENERATION_SLACK)
    )
    JuMP.set_lower_bound.(m[HYDRO_MIN_GENERATION_SLACK], 0)

    JuMP.@constraint(
        m,
        [n = 1:num_hydros],
        m[HYDRO_GENERATION][n] + m[HYDRO_MIN_GENERATION_SLACK][n] >=
            ses.entities[n].min_generation
    )
end

function add_hydro_balance!(m::JuMP.Model, hydros::Hydros)
    num_hydros = length(hydros)

    m[HYDRO_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_hydros],
        m[STORED_VOLUME][n].out ==
            m[STORED_VOLUME][n].in - m[OUTFLOW][n] +
        m[INFLOW][n] +
        sum(
            m[OUTFLOW][j] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
        )
    )
    return nothing
end

function add_system_elements!(m::JuMP.Model, s::SystemData)
    add_system_elements!(m, get_buses(s))
    add_system_elements!(m, get_lines(s))
    add_system_elements!(m, get_thermals(s))
    add_system_elements!(m, get_hydros(s))
    add_hydro_balance!(m, get_hydros(s))
    return true
end

function add_system_objective!(m::JuMP.Model, s::SystemData)
    hydros = get_hydros_entities(s)
    buses = get_buses_entities(s)
    lines = get_lines_entities(s)
    thermals = get_thermals_entities(s)
    num_buses = length(buses)
    num_lines = length(lines)
    num_hydros = length(hydros)
    num_thermals = length(thermals)

    SDDP.@stageobjective(
        m,
        sum(thermals[n].cost * m[THERMAL_GENERATION][n] for n in 1:num_thermals) +
            sum(buses[n].deficit_cost * m[DEFICIT][n] for n in 1:num_buses) +
            sum(lines[n].exchange_penalty * m[DIRECT_EXCHANGE][n] for n in 1:num_lines) +
            sum(lines[n].exchange_penalty * m[REVERSE_EXCHANGE][n] for n in 1:num_lines) +
            sum(
                hydros[n].bus[].deficit_cost * 1.0001 * m[HYDRO_MIN_GENERATION_SLACK][n] for
                n in 1:num_hydros
            ) +
            sum(hydros[n].spillage_penalty * m[SPILLAGE][n] for n in 1:num_hydros)
    )
    # @objective(
    #     m,
    #     sum(thermals[n].cost * m[THERMAL_GENERATION][n] for n in 1:num_thermals) +
    #         sum(buses[n].deficit_cost * m[DEFICIT][n] for n in 1:num_buses) +
    #         sum(lines[n].exchange_penalty * m[DIRECT_EXCHANGE][n] for n in 1:num_lines) +
    #         sum(lines[n].exchange_penalty * m[REVERSE_EXCHANGE][n] for n in 1:num_lines) +
    #         sum(
    #             hydros[n].bus[].deficit_cost * 1.0001 * m[HYDRO_MIN_GENERATION_SLACK][n] for
    #             n in 1:num_hydros
    #         ) +
    #         sum(hydros[n].spillage_penalty * m[SPILLAGE][n] for n in 1:num_hydros)
    # )
end

# HELPERS -------------------------------------------------------------------------------------

function __build_graph(files::Vector{InputModule})::SDDP.Graph
    g = get_graph(get_scenarios(files))
    root_node_id = get_root_node_id(g)
    graph = SDDP.Graph(root_node_id)

    for n in g.nodes
        if n.id !== root_node_id
            SDDP.add_node(graph, n.id)
        end
    end
    for e in g.edges
        SDDP.add_edge(graph, e.source[].id => e.target[].id, e.probability)
    end

    return graph
end

function __generate_subproblem_builder(files::Vector{InputModule})::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    num_stages = get_number_of_stages(get_graph(scenarios))

    set_seed!(scenarios)

    SAA = generate_saa(scenarios, num_stages)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios, node)

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

    m[LOAD_BALANCE] = JuMP.JuMP.@constraint(
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