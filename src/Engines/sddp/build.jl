function Lab.build(engine::SDDPEngine, files::Vector{InputModule}, optimizer)::SDDPModel
    @info "Compiling model"

    scaling_mode = engine.policy.scaling
    scaling_config, build_files = _apply_engine_scaling(scaling_mode, files)

    graph = __build_graph(build_files)
    sp_builder = __generate_subproblem_builder(build_files, scaling_config)
    model = SDDP.PolicyGraph(
        sp_builder, graph; sense = :Min, lower_bound = 0.0, optimizer = optimizer
    )

    return SDDPModel(model, scaling_config)
end

function Lab.build(engine::SDDPEngine, files::Vector{InputModule})::SDDPModel
    optimizer = create_optimizer(engine.solver)
    return Lab.build(engine, files, optimizer)
end

function _apply_engine_scaling(
    ::NoScaling, files::Vector{InputModule}
)::Tuple{ScalingConfig,Vector{InputModule}}
    return (no_scaling_config(), files)
end

function _apply_engine_scaling(
    ::AutoScaling, files::Vector{InputModule}
)::Tuple{ScalingConfig,Vector{InputModule}}
    system = get_system(files)
    config = compute_scaling_factors(system)
    scaled_system = apply_scaling(system, config)

    scaled_files = InputModule[]
    for f in files
        if f isa SystemData
            push!(scaled_files, scaled_system)
        else
            push!(scaled_files, f)
        end
    end

    @info "AutoScaling applied" factors = config.factors
    return (config, scaled_files)
end

function add_system_elements!(m::JuMP.Model, ses::Buses)
    num_buses = length(ses)

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
        # Bounds apply only to .out; the .in half is internally fixed by SDDP.jl
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
    return nothing
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
end

function add_inflow_uncertainty!(m::JuMP.Model, s::Naive, ::Int)::JuMP.Model
    n_hydro = length(s)

    m[ω_INFLOW] = JuMP.@variable(m, [1:n_hydro], base_name = String(ω_INFLOW))

    JuMP.@constraint(m, inflow_model, m[INFLOW] .== m[ω_INFLOW])

    return m
end

function __get_lag_scales(s::AutoRegressive, season::Int)
    lag_scales = []
    N, P, M_Ls = size(s)
    for n in 1:N
        aux = []
        for l in 1:M_Ls[n]
            ls = __lagged_season(season, l, P)
            push!(aux, get_ar_scale(s.signal_model[n], ls))
        end
        push!(lag_scales, aux)
    end

    return lag_scales
end

function add_inflow_uncertainty!(m::JuMP.Model, s::AutoRegressive,
    season::Int)

    n_hydro, period, max_lags = size(s)
    stchp_size = sum(max_lags)
    
    scales = get_ar_scale(s, season)
    inits = vcat([uar.initial_values for uar in s.signal_model]...)

    index_t = ones(Int,length(s))
    for i in 1:(length(s) - 1)
        index_t[i+1] = sum(max_lags[1:i]) + 1
    end
    memory_states = [n for n in 1:stchp_size if !(n in index_t)]
    
    m[ω_INFLOW] = JuMP.@variable(m, [1:n_hydro], base_name = String(ω_INFLOW))
    m[STCHP] = JuMP.@variable(m,
        [n = 1:stchp_size],
        base_name = String(STCHP),
        SDDP.State,
        initial_value = inits[n])

    lagged_scales = __get_lag_scales(s, season)
    ar_coefs = get_ar_parameters(s, season, true)

    for (n, t) in enumerate(zip(ar_coefs, lagged_scales, index_t, max_lags))
        ar_c, l_s, i, m_l = t
        s_t = scales[n]
        JuMP.@constraint(m,
            (m[STCHP][i].out - s_t[1]) / s_t[2] == 
                sum(ar_c[l] * (m[STCHP][i + l - 1].in - l_s[l][1]) / l_s[l][2] for l in 1:m_l) +
                m[ω_INFLOW][n],
            base_name = "ar_main" * string(n))
    end
    JuMP.@constraint(m, inflow[n = 1:n_hydro], m[INFLOW][n] == m[STCHP][index_t[n]].out)

    JuMP.@constraint(m, ar_memory[n in memory_states], m[STCHP][n].out == m[STCHP][n - 1].in)

    return m
end

function generate_saa(scenarios::ScenariosData, num_stages::Integer)
    inflow = scenarios.inflow.stochastic_process
    initial_season = scenarios.initial_season
    branchings = scenarios.branchings
    return StochasticProcess.generate_saa(inflow, initial_season, num_stages, branchings)
end

function generate_saa(scenarios::ScenariosData, num_stages::Integer, seed::Integer)
    inflow = scenarios.inflow.stochastic_process
    initial_season = scenarios.initial_season
    branchings = scenarios.branchings
    return StochasticProcess.generate_saa(inflow, initial_season, num_stages, branchings, seed)
end

function add_uncertainties!(m::JuMP.Model, scenarios::ScenariosData, node::Int)
    inflow = scenarios.inflow.stochastic_process

    season = __node2season(node, size(inflow, 2), scenarios.initial_season)
    return add_inflow_uncertainty!(m, inflow, season)
end

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

"""
    _build_bus_index_map(entities, bus_ids, bus_field::Symbol) -> Dict{Int, Vector{Int}}

Build a mapping from bus position index (1-based position in `bus_ids`) to the indices of
`entities` whose `bus_field` matches that bus id. Precomputed once to avoid repeated
O(num_entities) iteration per bus per subproblem node in `__add_load_balance!`.

# Arguments
- `entities`: Vector of system entities (e.g., `Vector{Hydro}`, `Vector{Thermal}`, etc.)
- `bus_ids`: Vector of bus ids in bus-position order (from `get_ids(get_buses(system))`)
- `bus_field`: Field name on the entity that holds the bus id (e.g., `:bus_id`, `:target_bus_id`)

# Returns
`Dict{Int, Vector{Int}}` mapping bus position `n` to `[j1, j2, ...]` where
`getfield(entities[ji], bus_field) == bus_ids[n]`.
"""
function _build_bus_index_map(
    entities::AbstractVector, bus_ids::Vector{<:Integer}, bus_field::Symbol
)::Dict{Int,Vector{Int}}
    map = Dict{Int,Vector{Int}}()
    for (j, entity) in enumerate(entities)
        bid = getfield(entity, bus_field)
        for (n, bus_id) in enumerate(bus_ids)
            if bid == bus_id
                indices = get!(map, n, Int[])
                push!(indices, j)
            end
        end
    end
    return map
end

function __generate_subproblem_builder(
    files::Vector{InputModule}, scaling::ScalingConfig
)::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    num_stages = get_number_of_stages(get_graph(scenarios))

    SAA = generate_saa(scenarios, num_stages, scenarios.seed)

    s_flow = get_scaling_factor(scaling, FLOW_SCALE)
    if s_flow != DEFAULT_SCALING_FACTOR
        for node in eachindex(SAA)
            SAA[node] = SAA[node] ./ s_flow
        end
    end

    s_gen = get_scaling_factor(scaling, HYDRO_GENERATION)

    hydros_entities = get_hydros_entities(system)
    thermals_entities = get_thermals_entities(system)
    lines_entities = get_lines_entities(system)
    bus_ids = get_ids(get_buses(system))

    hydro_bus_map = _build_bus_index_map(hydros_entities, bus_ids, :bus_id)
    thermal_bus_map = _build_bus_index_map(thermals_entities, bus_ids, :bus_id)
    line_target_map = _build_bus_index_map(lines_entities, bus_ids, :target_bus_id)
    line_source_map = _build_bus_index_map(lines_entities, bus_ids, :source_bus_id)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        add_system_elements!(m, system)
        add_uncertainties!(m, scenarios, node)

        __add_load_balance!(
            m, scenarios, node, s_gen, bus_ids,
            hydro_bus_map, thermal_bus_map, line_target_map, line_source_map
        )

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[ω_INFLOW], ω)
        end

        add_system_objective!(m, system)

        return nothing
    end

    return fun_sp_build
end

function __add_load_balance!(
    m::JuMP.Model,
    scenarios::ScenariosData,
    node::Integer,
    load_scale::Float64,
    bus_ids::Vector{<:Integer},
    hydro_bus_map::Dict{Int,Vector{Int}},
    thermal_bus_map::Dict{Int,Vector{Int}},
    line_target_map::Dict{Int,Vector{Int}},
    line_source_map::Dict{Int,Vector{Int}},
)
    num_buses = length(bus_ids)

    m[LOAD_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_buses],
        sum(m[HYDRO_GENERATION][j] for j in get(hydro_bus_map, n, Int[])) +
        sum(m[THERMAL_GENERATION][j] for j in get(thermal_bus_map, n, Int[])) +
        sum(
            m[DIRECT_EXCHANGE][j] - m[REVERSE_EXCHANGE][j]
            for j in get(line_target_map, n, Int[])
        ) +
        sum(
            m[REVERSE_EXCHANGE][j] - m[DIRECT_EXCHANGE][j]
            for j in get(line_source_map, n, Int[])
        ) +
        m[DEFICIT][bus_ids[n]] == get_load(bus_ids[n], node, scenarios) / load_scale
    )
    return nothing
end