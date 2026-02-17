const DEFAULT_SCALING_FACTOR = 1.0
const MIN_SCALING_FACTOR = 1e-10
const COST_SCALE = Symbol("COST_SCALE")
const FLOW_SCALE = Symbol("FLOW_SCALE")

function _safe_scaling_factor(value::Real)::Float64
    v = Float64(value)
    if v < MIN_SCALING_FACTOR
        @warn "Scaling factor $v is below minimum threshold $MIN_SCALING_FACTOR, defaulting to $DEFAULT_SCALING_FACTOR"
        return DEFAULT_SCALING_FACTOR
    end
    return v
end

"""
    compute_scaling_factors(system) -> ScalingConfig

Compute per-category scaling factors so that LP coefficients lie in a
well-conditioned range. Storage and flow share one factor (hydro balance
links them); generation categories share another.
"""
function compute_scaling_factors(system::SystemData)::ScalingConfig
    factors = Dict{Symbol,Float64}()

    hydros = get_hydros_entities(system)
    thermals = get_thermals_entities(system)
    buses = get_buses_entities(system)
    lines = get_lines_entities(system)

    all_gen = Float64[]
    for h in hydros
        push!(all_gen, Float64(h.max_generation))
    end
    for t in thermals
        push!(all_gen, Float64(t.max_generation))
    end
    max_gen = isempty(all_gen) ? DEFAULT_SCALING_FACTOR : maximum(all_gen)
    factors[HYDRO_GENERATION] = _safe_scaling_factor(max_gen)
    factors[THERMAL_GENERATION] = _safe_scaling_factor(max_gen)
    factors[DEFICIT] = _safe_scaling_factor(max_gen)

    # Unified storage/flow factor: hydro balance links v, outflow, and inflow
    max_stor = isempty(hydros) ? DEFAULT_SCALING_FACTOR :
               maximum(h.max_storage for h in hydros)
    flow_values = Float64[]
    for h in hydros
        if h.productivity > MIN_SCALING_FACTOR
            push!(flow_values, Float64(h.max_generation / h.productivity))
        end
    end
    max_flow = isempty(flow_values) ? DEFAULT_SCALING_FACTOR : maximum(flow_values)

    s_hydro = max(
        _safe_scaling_factor(max_stor),
        _safe_scaling_factor(max_flow),
    )
    factors[STORED_VOLUME] = s_hydro
    factors[FLOW_SCALE] = s_hydro
    factors[TURBINED_FLOW] = s_hydro
    factors[SPILLAGE] = s_hydro
    factors[OUTFLOW] = s_hydro
    factors[INFLOW] = s_hydro

    max_cap = isempty(lines) ? DEFAULT_SCALING_FACTOR :
              maximum(l.capacity for l in lines; init = DEFAULT_SCALING_FACTOR)
    max_cap = max_cap < MIN_SCALING_FACTOR ? DEFAULT_SCALING_FACTOR : max_cap
    factors[DIRECT_EXCHANGE] = _safe_scaling_factor(max_cap)
    factors[REVERSE_EXCHANGE] = _safe_scaling_factor(max_cap)

    all_costs = Float64[]
    for t in thermals
        push!(all_costs, Float64(t.cost))
    end
    for b in buses
        push!(all_costs, Float64(b.deficit_cost))
    end
    max_cost = isempty(all_costs) ? DEFAULT_SCALING_FACTOR : maximum(all_costs)
    factors[COST_SCALE] = _safe_scaling_factor(max_cost)

    return ScalingConfig(factors)
end

function no_scaling_config()::ScalingConfig
    factors = Dict{Symbol,Float64}(
        STORED_VOLUME => DEFAULT_SCALING_FACTOR,
        HYDRO_GENERATION => DEFAULT_SCALING_FACTOR,
        THERMAL_GENERATION => DEFAULT_SCALING_FACTOR,
        DEFICIT => DEFAULT_SCALING_FACTOR,
        FLOW_SCALE => DEFAULT_SCALING_FACTOR,
        TURBINED_FLOW => DEFAULT_SCALING_FACTOR,
        SPILLAGE => DEFAULT_SCALING_FACTOR,
        OUTFLOW => DEFAULT_SCALING_FACTOR,
        INFLOW => DEFAULT_SCALING_FACTOR,
        DIRECT_EXCHANGE => DEFAULT_SCALING_FACTOR,
        REVERSE_EXCHANGE => DEFAULT_SCALING_FACTOR,
        COST_SCALE => DEFAULT_SCALING_FACTOR,
    )
    return ScalingConfig(factors)
end

function get_scaling_factor(config::ScalingConfig, sym::Symbol)::Float64
    return get(config.factors, sym, DEFAULT_SCALING_FACTOR)
end

"""
    apply_scaling(system, config) -> SystemData

Return a new `SystemData` with all parameters divided by the corresponding
scaling factors.  Productivity is adjusted so `gen_scaled = prod_scaled * flow_scaled`.
"""
function apply_scaling(system::SystemData, config::ScalingConfig)::SystemData
    s_stor = get_scaling_factor(config, STORED_VOLUME)
    s_hgen = get_scaling_factor(config, HYDRO_GENERATION)
    s_tgen = get_scaling_factor(config, THERMAL_GENERATION)
    s_flow = get_scaling_factor(config, FLOW_SCALE)
    s_exch = get_scaling_factor(config, DIRECT_EXCHANGE)
    s_cost = get_scaling_factor(config, COST_SCALE)

    scaled_buses = Bus[
        Bus(
            b.id,
            b.name,
            b.deficit_cost / s_cost,
        ) for b in system.buses.entities
    ]
    new_buses = Buses(scaled_buses)

    # exch_pen_scaled = exch_pen * s_exch / (s_cost * s_hgen)
    scaled_lines = Line[
        Line(
            l.id,
            l.name,
            l.source_bus_id,
            l.target_bus_id,
            l.capacity / s_exch,
            l.exchange_penalty * s_exch / (s_cost * s_hgen),
            Ref(scaled_buses[findfirst(b -> b.id == l.source_bus_id, scaled_buses)]),
            Ref(scaled_buses[findfirst(b -> b.id == l.target_bus_id, scaled_buses)]),
        ) for l in system.lines.entities
    ]
    new_lines = Lines(scaled_lines)

    # prod_scaled = prod * s_flow / s_hgen
    # spill_pen_scaled = spill_pen * s_flow / (s_cost * s_hgen)
    scaled_hydros = Hydro[
        Hydro(
            h.id,
            h.downstream_id,
            h.name,
            h.bus_id,
            h.productivity * s_flow / s_hgen,
            h.initial_storage / s_stor,
            h.min_storage / s_stor,
            h.max_storage / s_stor,
            h.min_generation / s_hgen,
            h.max_generation / s_hgen,
            h.spillage_penalty * s_flow / (s_cost * s_hgen),
            Ref(scaled_buses[findfirst(b -> b.id == h.bus_id, scaled_buses)]),
        ) for h in system.hydros.entities
    ]
    new_hydros = Hydros(scaled_hydros, system.hydros.topology)

    scaled_thermals = Thermal[
        Thermal(
            t.id,
            t.name,
            t.bus_id,
            t.min_generation / s_tgen,
            t.max_generation / s_tgen,
            t.cost / s_cost,
            Ref(scaled_buses[findfirst(b -> b.id == t.bus_id, scaled_buses)]),
        ) for t in system.thermals.entities
    ]
    new_thermals = Thermals(scaled_thermals)

    return SystemData(new_buses, new_lines, new_hydros, new_thermals)
end
