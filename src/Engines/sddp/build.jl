function Lab.build(engine::SDDPEngine, files::Vector{InputModule}, optimizer)::SDDPModel
    @info "Compiling model"

    scaling_mode = engine.policy.scaling
    scaling_config, build_files = _apply_engine_scaling(scaling_mode, files)
    inflow_method = engine.inflow_non_negativity

    graph = __build_graph(build_files)
    sp_builder = __generate_subproblem_builder(build_files, scaling_config, inflow_method)
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

    scaled_files = [f isa SystemData ? scaled_system : f for f in files]

    @info "AutoScaling applied" factors = config.factors
    return (config, scaled_files)
end

function add_system_elements!(m::JuMP.Model, ses::Buses, num_blocks::Int)
    num_buses = length(ses)

    m[LOAD] = JuMP.@variable(m, [1:num_buses, 1:num_blocks], base_name = String(LOAD))
    m[DEFICIT] = JuMP.@variable(m, [1:num_buses, 1:num_blocks], base_name = String(DEFICIT))

    for n in 1:num_buses, k in 1:num_blocks
        JuMP.set_lower_bound(m[DEFICIT][n, k], 0)
    end

    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::Lines, num_blocks::Int)
    num_lines = length(ses)

    m[DIRECT_EXCHANGE] = JuMP.@variable(
        m, [1:num_lines, 1:num_blocks], base_name = String(DIRECT_EXCHANGE)
    )
    for n in 1:num_lines, k in 1:num_blocks
        JuMP.set_lower_bound(m[DIRECT_EXCHANGE][n, k], 0)
        JuMP.set_upper_bound(m[DIRECT_EXCHANGE][n, k], ses.entities[n].capacity)
    end

    m[REVERSE_EXCHANGE] = JuMP.@variable(
        m, [1:num_lines, 1:num_blocks], base_name = String(REVERSE_EXCHANGE)
    )
    for n in 1:num_lines, k in 1:num_blocks
        JuMP.set_lower_bound(m[REVERSE_EXCHANGE][n, k], 0)
        JuMP.set_upper_bound(m[REVERSE_EXCHANGE][n, k], ses.entities[n].capacity)
    end

    m[NET_EXCHANGE] = JuMP.@expression(
        m, [n = 1:num_lines, k = 1:num_blocks],
        m[DIRECT_EXCHANGE][n, k] - m[REVERSE_EXCHANGE][n, k]
    )
end

function add_system_elements!(m::JuMP.Model, ses::Thermals, num_blocks::Int)
    num_thermals = length(ses)
    m[THERMAL_GENERATION] = JuMP.@variable(
        m, [1:num_thermals, 1:num_blocks], base_name = String(THERMAL_GENERATION)
    )
    for n in 1:num_thermals, k in 1:num_blocks
        JuMP.set_lower_bound(m[THERMAL_GENERATION][n, k], ses.entities[n].min_generation)
        JuMP.set_upper_bound(m[THERMAL_GENERATION][n, k], ses.entities[n].max_generation)
    end

    m[THERMAL_GENERATION_COST] = JuMP.@expression(
        m, [n = 1:num_thermals, k = 1:num_blocks],
        ses.entities[n].cost * m[THERMAL_GENERATION][n, k]
    )

    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::NonControllables, num_blocks::Int)
    num_nc = length(ses)
    if num_nc == 0
        return nothing
    end
    m[NC_GENERATION] = JuMP.@variable(
        m, [1:num_nc, 1:num_blocks], base_name = String(NC_GENERATION)
    )
    for n in 1:num_nc, k in 1:num_blocks
        JuMP.set_lower_bound(m[NC_GENERATION][n, k], 0)
        JuMP.set_upper_bound(m[NC_GENERATION][n, k], ses.entities[n].max_generation)
    end

    m[NC_CURTAILMENT] = JuMP.@expression(
        m, [n = 1:num_nc, k = 1:num_blocks],
        ses.entities[n].max_generation - m[NC_GENERATION][n, k]
    )

    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::EnergyContracts, num_blocks::Int)
    num_contracts = length(ses)
    if num_contracts == 0
        return nothing
    end
    m[CONTRACT_DISPATCH] = JuMP.@variable(
        m, [1:num_contracts, 1:num_blocks], base_name = String(CONTRACT_DISPATCH)
    )
    for n in 1:num_contracts, k in 1:num_blocks
        JuMP.set_lower_bound(m[CONTRACT_DISPATCH][n, k], ses.entities[n].min_mw)
        JuMP.set_upper_bound(m[CONTRACT_DISPATCH][n, k], ses.entities[n].max_mw)
    end
    return nothing
end

function add_system_elements!(m::JuMP.Model, ses::Hydros, num_blocks::Int)
    num_hydros = length(ses)

    m[STORED_VOLUME] = JuMP.@variable(
        m,
        [n = 1:num_hydros],
        base_name = String(STORED_VOLUME),
        SDDP.State,
        initial_value = ses.entities[n].initial_storage
    )

    for n in 1:num_hydros
        JuMP.set_lower_bound(m[STORED_VOLUME][n].out, ses.entities[n].min_storage)
        JuMP.set_upper_bound(m[STORED_VOLUME][n].out, ses.entities[n].max_storage)
    end

    m[INFLOW] = JuMP.@variable(m, [1:num_hydros], base_name = String(INFLOW))

    m[TURBINED_FLOW] = JuMP.@variable(
        m, [1:num_hydros, 1:num_blocks], base_name = String(TURBINED_FLOW)
    )
    for n in 1:num_hydros, k in 1:num_blocks
        JuMP.set_lower_bound(m[TURBINED_FLOW][n, k], ses.entities[n].min_generation / ses.entities[n].productivity)
        JuMP.set_upper_bound(m[TURBINED_FLOW][n, k], ses.entities[n].max_generation / ses.entities[n].productivity)
    end

    m[SPILLAGE] = JuMP.@variable(
        m, [1:num_hydros, 1:num_blocks], base_name = String(SPILLAGE)
    )
    for n in 1:num_hydros, k in 1:num_blocks
        JuMP.set_lower_bound(m[SPILLAGE][n, k], 0)
    end

    m[OUTFLOW] = JuMP.@expression(
        m, [n = 1:num_hydros, k = 1:num_blocks],
        m[TURBINED_FLOW][n, k] + m[SPILLAGE][n, k]
    )

    m[HYDRO_GENERATION] = JuMP.@expression(
        m, [n = 1:num_hydros, k = 1:num_blocks],
        ses.entities[n].productivity * m[TURBINED_FLOW][n, k]
    )

    m[HYDRO_MIN_GENERATION_SLACK] = JuMP.@variable(
        m, [1:num_hydros, 1:num_blocks], base_name = String(HYDRO_MIN_GENERATION_SLACK)
    )
    for n in 1:num_hydros, k in 1:num_blocks
        JuMP.set_lower_bound(m[HYDRO_MIN_GENERATION_SLACK][n, k], 0)
    end

    JuMP.@constraint(
        m,
        [n = 1:num_hydros, k = 1:num_blocks],
        m[HYDRO_GENERATION][n, k] + m[HYDRO_MIN_GENERATION_SLACK][n, k] >=
            ses.entities[n].min_generation
    )
end

function add_system_elements!(m::JuMP.Model, ses::PumpingStations, num_blocks::Int)
    num_stations = length(ses)
    if num_stations == 0
        return nothing
    end
    m[PUMPED_FLOW] = JuMP.@variable(
        m, [1:num_stations, 1:num_blocks], base_name = String(PUMPED_FLOW)
    )
    for n in 1:num_stations, k in 1:num_blocks
        JuMP.set_lower_bound(m[PUMPED_FLOW][n, k], ses.entities[n].min_m3s)
        JuMP.set_upper_bound(m[PUMPED_FLOW][n, k], ses.entities[n].max_m3s)
    end
    m[PUMP_POWER] = JuMP.@expression(
        m, [n = 1:num_stations, k = 1:num_blocks],
        ses.entities[n].consumption_mw_per_m3s * m[PUMPED_FLOW][n, k]
    )
    return nothing
end

function add_system_elements!(m::JuMP.Model, s::SystemData, num_blocks::Int)
    add_system_elements!(m, get_buses(s), num_blocks)
    add_system_elements!(m, get_lines(s), num_blocks)
    add_system_elements!(m, get_thermals(s), num_blocks)
    add_system_elements!(m, get_noncontrollables(s), num_blocks)
    add_system_elements!(m, get_energycontracts(s), num_blocks)
    add_system_elements!(m, get_pumpingstations(s), num_blocks)
    add_system_elements!(m, get_hydros(s), num_blocks)
    return nothing
end

function add_hydro_balance_parallel!(
    m::JuMP.Model, hydros::Hydros,
    pump_source_map::Dict{Int,Vector{Int}},
    pump_dest_map::Dict{Int,Vector{Int}},
    zeta::Float64,
    w_k::Vector{Float64},
    num_blocks::Int,
)
    num_hydros = length(hydros)

    m[HYDRO_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_hydros],
        m[STORED_VOLUME][n].out ==
            m[STORED_VOLUME][n].in +
            zeta * m[INFLOW][n] -
            zeta * sum(
                w_k[k] * m[OUTFLOW][n, k] for k in 1:num_blocks
            ) +
            zeta * sum(
                w_k[k] * m[OUTFLOW][j, k]
                for j in 1:num_hydros if downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
                for k in 1:num_blocks
            ) -
            zeta * sum(
                w_k[k] * m[PUMPED_FLOW][j, k]
                for j in get(pump_source_map, n, Int[])
                for k in 1:num_blocks
            ) +
            zeta * sum(
                w_k[k] * m[PUMPED_FLOW][j, k]
                for j in get(pump_dest_map, n, Int[])
                for k in 1:num_blocks
            )
    )
    return nothing
end

function add_hydro_balance_chronological!(
    m::JuMP.Model, hydros::Hydros,
    pump_source_map::Dict{Int,Vector{Int}},
    pump_dest_map::Dict{Int,Vector{Int}},
    zeta_k::Vector{Float64},
    w_k::Vector{Float64},
    num_blocks::Int,
)
    num_hydros = length(hydros)
    K = num_blocks

    if K > 1
        m[BLOCK_STORAGE] = JuMP.@variable(
            m, [1:num_hydros, 1:(K - 1)], base_name = String(BLOCK_STORAGE)
        )
        for n in 1:num_hydros, k in 1:(K - 1)
            JuMP.set_lower_bound(m[BLOCK_STORAGE][n, k], hydros.entities[n].min_storage)
            JuMP.set_upper_bound(m[BLOCK_STORAGE][n, k], hydros.entities[n].max_storage)
        end
    end

    function _prev_vol(n, k)
        return k == 1 ? m[STORED_VOLUME][n].in : m[BLOCK_STORAGE][n, k - 1]
    end

    function _curr_vol(n, k)
        return k == K ? m[STORED_VOLUME][n].out : m[BLOCK_STORAGE][n, k]
    end

    function _net_flow_expr(n, k)
        upstream_flow = sum(
            m[OUTFLOW][j, k]
            for j in 1:num_hydros if downstream(hydros.entities[j].id, hydros) == hydros.entities[n];
            init = 0.0
        )
        source_pump = sum(
            m[PUMPED_FLOW][j, k] for j in get(pump_source_map, n, Int[]); init = 0.0
        )
        dest_pump = sum(
            m[PUMPED_FLOW][j, k] for j in get(pump_dest_map, n, Int[]); init = 0.0
        )
        return upstream_flow - m[OUTFLOW][n, k] - source_pump + dest_pump
    end

    m[HYDRO_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_hydros, k = 1:K],
        _curr_vol(n, k) ==
            _prev_vol(n, k) +
            zeta_k[k] * w_k[k] * m[INFLOW][n] +
            zeta_k[k] * _net_flow_expr(n, k)
    )
    return nothing
end

function add_hydro_balance!(
    m::JuMP.Model, hydros::Hydros,
    pump_source_map::Dict{Int,Vector{Int}},
    pump_dest_map::Dict{Int,Vector{Int}},
    block_mode::Symbol,
    tau_k::Vector{Float64},
    num_blocks::Int,
)
    w_k = get_block_weights(tau_k)

    if block_mode == :parallel
        zeta = 0.0036 * sum(tau_k)
        add_hydro_balance_parallel!(
            m, hydros, pump_source_map, pump_dest_map, zeta, w_k, num_blocks
        )
    elseif block_mode == :chronological
        zeta_k = 0.0036 .* tau_k
        add_hydro_balance_chronological!(
            m, hydros, pump_source_map, pump_dest_map, zeta_k, w_k, num_blocks
        )
    else
        error("Unknown block mode: $block_mode. Expected :parallel or :chronological.")
    end
    return nothing
end

function _inflow_penalty_expr(
    m::JuMP.Model, ::InflowNone, ::Vector{Float64}, ::ScalingConfig
)
    return 0.0
end

function _inflow_penalty_expr(
    m::JuMP.Model, ::InflowTruncation, ::Vector{Float64}, ::ScalingConfig
)
    return 0.0
end

function _inflow_penalty_expr(
    m::JuMP.Model, method::InflowPenalty, tau_k::Vector{Float64}, scaling::ScalingConfig
)
    if !haskey(JuMP.object_dictionary(m), INFLOW_SLACK)
        return 0.0
    end
    zeta = 0.0036 * sum(tau_k)
    n_hydro = length(m[INFLOW_SLACK])
    s_cost = get_scaling_factor(scaling, COST_SCALE)
    s_gen = get_scaling_factor(scaling, HYDRO_GENERATION)
    s_flow = get_scaling_factor(scaling, FLOW_SCALE)
    scaled_coeff = method.penalty_cost * zeta * s_flow / (s_cost * s_gen)
    return scaled_coeff * sum(m[INFLOW_SLACK][n] for n in 1:n_hydro)
end

function _inflow_penalty_expr(
    m::JuMP.Model,
    method::InflowTruncationWithPenalty,
    tau_k::Vector{Float64},
    scaling::ScalingConfig,
)
    if !haskey(JuMP.object_dictionary(m), NOISE_ADJUSTMENT_SLACK)
        return 0.0
    end
    zeta = 0.0036 * sum(tau_k)
    n_hydro = length(m[NOISE_ADJUSTMENT_SLACK])
    sigma_values = m.ext[:noise_adjustment_sigma]::Vector{Float64}
    s_cost = get_scaling_factor(scaling, COST_SCALE)
    s_gen = get_scaling_factor(scaling, HYDRO_GENERATION)
    return sum(
        method.penalty_cost * zeta * sigma_values[n] / (s_cost * s_gen) *
        m[NOISE_ADJUSTMENT_SLACK][n] for n in 1:n_hydro
    )
end

function add_system_objective!(
    m::JuMP.Model,
    s::SystemData,
    tau_k::Vector{Float64},
    method::InflowNonNegativity,
    scaling::ScalingConfig,
)
    hydros = get_hydros_entities(s)
    buses = get_buses_entities(s)
    lines = get_lines_entities(s)
    thermals = get_thermals_entities(s)
    noncontrollables = get_noncontrollables_entities(s)
    contracts = get_energycontracts_entities(s)
    num_buses = length(buses)
    num_lines = length(lines)
    num_hydros = length(hydros)
    num_thermals = length(thermals)
    num_nc = length(noncontrollables)
    num_contracts = length(contracts)
    K = length(tau_k)

    penalty = _inflow_penalty_expr(m, method, tau_k, scaling)

    SDDP.@stageobjective(
        m,
        sum(
            tau_k[k] * sum(thermals[n].cost * m[THERMAL_GENERATION][n, k] for n in 1:num_thermals) +
            tau_k[k] * sum(buses[n].deficit_cost * m[DEFICIT][n, k] for n in 1:num_buses) +
            tau_k[k] * sum(lines[n].exchange_penalty * m[DIRECT_EXCHANGE][n, k] for n in 1:num_lines) +
            tau_k[k] * sum(lines[n].exchange_penalty * m[REVERSE_EXCHANGE][n, k] for n in 1:num_lines) +
            tau_k[k] * sum(
                hydros[n].bus[].deficit_cost * 1.0001 * m[HYDRO_MIN_GENERATION_SLACK][n, k] for
                n in 1:num_hydros
            ) +
            tau_k[k] * sum(hydros[n].spillage_penalty * m[SPILLAGE][n, k] for n in 1:num_hydros) +
            tau_k[k] * (num_nc > 0 ? sum(noncontrollables[n].curtailment_cost * m[NC_CURTAILMENT][n, k] for n in 1:num_nc) : 0.0) +
            tau_k[k] * (num_contracts > 0 ? sum(contracts[n].price_per_mwh * m[CONTRACT_DISPATCH][n, k] for n in 1:num_contracts) : 0.0)
            for k in 1:K
        ) + penalty
    )
end

function add_inflow_uncertainty!(
    m::JuMP.Model, s::Naive, ::Int, method::InflowNonNegativity
)::JuMP.Model
    if !(method isa InflowNone)
        @warn "Inflow non-negativity method $(typeof(method)) is not applicable to Naive stochastic process. Falling back to InflowNone."
    end
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

function add_inflow_uncertainty!(
    m::JuMP.Model, s::AutoRegressive, season::Int, method::InflowNonNegativity
)
    n_hydro, period, max_lags = size(s)
    stchp_size = sum(max_lags)

    scales = get_ar_scale(s, season)
    inits = vcat([uar.initial_values for uar in s.signal_model]...)

    index_t = ones(Int, length(s))
    for i in 1:(length(s) - 1)
        index_t[i + 1] = sum(max_lags[1:i]) + 1
    end
    memory_states = [n for n in 1:stchp_size if !(n in index_t)]

    m[ω_INFLOW] = JuMP.@variable(m, [1:n_hydro], base_name = String(ω_INFLOW))
    m[STCHP] = JuMP.@variable(
        m,
        [n = 1:stchp_size],
        base_name = String(STCHP),
        SDDP.State,
        initial_value = inits[n],
    )

    lagged_scales = __get_lag_scales(s, season)
    ar_coefs = get_ar_parameters(s, season, true)

    if method isa InflowTruncationWithPenalty
        m[NOISE_ADJUSTMENT_SLACK] = JuMP.@variable(
            m, [1:n_hydro], base_name = String(NOISE_ADJUSTMENT_SLACK)
        )
        for n in 1:n_hydro
            JuMP.set_lower_bound(m[NOISE_ADJUSTMENT_SLACK][n], 0)
        end

        sigma_values = Float64[scales[n][2] for n in 1:n_hydro]
        m.ext[:noise_adjustment_sigma] = sigma_values

        for (n, t) in enumerate(zip(ar_coefs, lagged_scales, index_t, max_lags))
            ar_c, l_s, i, m_l = t
            s_t = scales[n]
            JuMP.@constraint(
                m,
                (m[STCHP][i].out - s_t[1]) / s_t[2] ==
                    sum(
                        ar_c[l] * (m[STCHP][i + l - 1].in - l_s[l][1]) / l_s[l][2]
                        for l in 1:m_l
                    ) +
                    m[ω_INFLOW][n] +
                    m[NOISE_ADJUSTMENT_SLACK][n],
                base_name = "ar_main" * string(n),
            )
        end
    else
        for (n, t) in enumerate(zip(ar_coefs, lagged_scales, index_t, max_lags))
            ar_c, l_s, i, m_l = t
            s_t = scales[n]
            JuMP.@constraint(
                m,
                (m[STCHP][i].out - s_t[1]) / s_t[2] ==
                    sum(
                        ar_c[l] * (m[STCHP][i + l - 1].in - l_s[l][1]) / l_s[l][2]
                        for l in 1:m_l
                    ) +
                    m[ω_INFLOW][n],
                base_name = "ar_main" * string(n),
            )
        end
    end

    if method isa InflowPenalty
        m[INFLOW_SLACK] = JuMP.@variable(
            m, [1:n_hydro], base_name = String(INFLOW_SLACK)
        )
        for n in 1:n_hydro
            JuMP.set_lower_bound(m[INFLOW_SLACK][n], 0)
            JuMP.set_lower_bound(m[INFLOW][n], 0)
        end
        JuMP.@constraint(
            m,
            inflow[n = 1:n_hydro],
            m[INFLOW][n] + m[INFLOW_SLACK][n] == m[STCHP][index_t[n]].out,
        )
    elseif method isa InflowTruncationWithPenalty
        for n in 1:n_hydro
            JuMP.set_lower_bound(m[INFLOW][n], 0)
        end
        JuMP.@constraint(
            m, inflow[n = 1:n_hydro], m[INFLOW][n] == m[STCHP][index_t[n]].out
        )
    else
        JuMP.@constraint(
            m, inflow[n = 1:n_hydro], m[INFLOW][n] == m[STCHP][index_t[n]].out
        )
    end

    JuMP.@constraint(
        m, ar_memory[n in memory_states], m[STCHP][n].out == m[STCHP][n - 1].in
    )

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

function add_uncertainties!(
    m::JuMP.Model, scenarios::ScenariosData, node::Int, method::InflowNonNegativity
)
    inflow = scenarios.inflow.stochastic_process

    season = __node2season(node, size(inflow, 2), scenarios.initial_season)
    return add_inflow_uncertainty!(m, inflow, season, method)
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
    files::Vector{InputModule}, scaling::ScalingConfig, method::InflowNonNegativity
)::Function
    system = get_system(files)
    scenarios = get_scenarios(files)
    graph = get_graph(scenarios)
    num_stages = get_number_of_stages(graph)
    block_config = get_block_config(scenarios)

    node_datetimes = Dict{Int,Tuple{DateTime,DateTime}}()
    for n in graph.nodes
        node_datetimes[n.id] = (n.start_datetime, n.end_datetime)
    end

    SAA = generate_saa(scenarios, num_stages, scenarios.seed)

    s_flow = get_scaling_factor(scaling, FLOW_SCALE)
    if s_flow != DEFAULT_SCALING_FACTOR
        for node in eachindex(SAA)
            SAA[node] = SAA[node] ./ s_flow
        end
    end

    if method isa InflowTruncation || method isa InflowTruncationWithPenalty
        for node in eachindex(SAA)
            SAA[node] = [max.(0.0, omega) for omega in SAA[node]]
        end
    end

    s_gen = get_scaling_factor(scaling, HYDRO_GENERATION)

    hydros_entities = get_hydros_entities(system)
    thermals_entities = get_thermals_entities(system)
    lines_entities = get_lines_entities(system)
    noncontrollable_entities = get_noncontrollables_entities(system)
    contracts_entities = get_energycontracts_entities(system)
    pumping_entities = get_pumpingstations_entities(system)
    bus_ids = get_ids(get_buses(system))
    hydro_ids = get_ids(get_hydros(system))

    hydro_bus_map = _build_bus_index_map(hydros_entities, bus_ids, :bus_id)
    thermal_bus_map = _build_bus_index_map(thermals_entities, bus_ids, :bus_id)
    noncontrollable_bus_map = _build_bus_index_map(noncontrollable_entities, bus_ids, :bus_id)
    contract_bus_map = _build_bus_index_map(contracts_entities, bus_ids, :bus_id)
    pumping_bus_map = _build_bus_index_map(pumping_entities, bus_ids, :bus_id)
    pump_source_map = _build_bus_index_map(pumping_entities, hydro_ids, :source_hydro_id)
    pump_dest_map = _build_bus_index_map(pumping_entities, hydro_ids, :destination_hydro_id)
    line_target_map = _build_bus_index_map(lines_entities, bus_ids, :target_bus_id)
    line_source_map = _build_bus_index_map(lines_entities, bus_ids, :source_bus_id)

    block_mode = block_config.mode
    K = num_blocks(block_config)

    function fun_sp_build(m::JuMP.Model, node::Integer)
        start_dt, end_dt = node_datetimes[node]
        tau = Float64(Dates.value(end_dt - start_dt)) / 3_600_000.0
        tau_k = get_block_durations(block_config, tau)

        add_system_elements!(m, system, K)
        add_hydro_balance!(
            m, get_hydros(system), pump_source_map, pump_dest_map,
            block_mode, tau_k, K
        )
        add_uncertainties!(m, scenarios, node, method)

        __add_load_balance!(
            m, scenarios, node, s_gen, bus_ids, K,
            hydro_bus_map, thermal_bus_map, noncontrollable_bus_map,
            line_target_map, line_source_map,
            contract_bus_map, contracts_entities,
            pumping_bus_map, pumping_entities
        )

        Ω_node = vec(SAA[node])
        SDDP.parameterize(m, Ω_node) do ω
            return JuMP.fix.(m[ω_INFLOW], ω)
        end

        add_system_objective!(m, system, tau_k, method, scaling)

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
    num_blocks::Int,
    hydro_bus_map::Dict{Int,Vector{Int}},
    thermal_bus_map::Dict{Int,Vector{Int}},
    noncontrollable_bus_map::Dict{Int,Vector{Int}},
    line_target_map::Dict{Int,Vector{Int}},
    line_source_map::Dict{Int,Vector{Int}},
    contract_bus_map::Dict{Int,Vector{Int}},
    contracts_entities::Vector{EnergyContract},
    pumping_bus_map::Dict{Int,Vector{Int}},
    pumping_entities::Vector{PumpingStation},
)
    num_buses = length(bus_ids)

    m[LOAD_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_buses, k = 1:num_blocks],
        sum(m[HYDRO_GENERATION][j, k] for j in get(hydro_bus_map, n, Int[])) +
        sum(m[THERMAL_GENERATION][j, k] for j in get(thermal_bus_map, n, Int[])) +
        sum(m[NC_GENERATION][j, k] for j in get(noncontrollable_bus_map, n, Int[])) +
        sum(
            contracts_entities[j].contract_type == "import" ? m[CONTRACT_DISPATCH][j, k] : -m[CONTRACT_DISPATCH][j, k]
            for j in get(contract_bus_map, n, Int[])
        ) -
        sum(m[PUMP_POWER][j, k] for j in get(pumping_bus_map, n, Int[])) +
        sum(
            m[DIRECT_EXCHANGE][j, k] - m[REVERSE_EXCHANGE][j, k]
            for j in get(line_target_map, n, Int[])
        ) +
        sum(
            m[REVERSE_EXCHANGE][j, k] - m[DIRECT_EXCHANGE][j, k]
            for j in get(line_source_map, n, Int[])
        ) +
        m[DEFICIT][n, k] == get_load(bus_ids[n], node, k, scenarios) / load_scale
    );
    return nothing
end
