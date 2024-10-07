# CLASS Hydro -----------------------------------------------------------------------

function Hydro(d::Dict{String,Any}, buses::Buses, e::CompositeException)

    # Build internal objects
    valid_internals = __build_hydro_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_hydro_keys_types!(d, e)

    # Content validation
    bus_ref = valid_keys_types ? __validate_hydro_content!(d, buses, e) : nothing
    valid_content = bus_ref !== nothing

    # Consistency validation
    valid_consistency = valid_content && __validate_hydro_consistency!(d, e)

    return if valid_consistency
        Hydro(
            d["id"],
            d["downstream_id"],
            d["name"],
            d["bus_id"],
            d["productivity"],
            d["initial_storage"],
            d["min_storage"],
            d["max_storage"],
            d["min_generation"],
            d["max_generation"],
            d["spillage_penalty"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS Hydros -----------------------------------------------------------------------

function Hydros(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    # Build internal objects
    valid_internals = __build_hydros_internals_from_dicts!(d, buses, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_hydros_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_hydros_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_hydros_consistency!(d, e)

    return valid_consistency ? Hydros(d["entities"], d["topology"]) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Hydro)::Integer
    return s.id
end

function get_params(s::Hydro)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "downstream_id" => s.downstream_id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "productivity" => s.productivity,
        "initial_storage" => s.initial_storage,
        "min_storage" => s.min_storage,
        "max_storage" => s.max_storage,
        "min_generation" => s.min_generation,
        "max_generation" => s.max_generation,
        "spillage_penalty" => s.spillage_penalty,
    )
end

function get_ids(ses::Hydros)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Hydros)::Integer
    return length(get_ids(ses))
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, ses::Hydros)
    num_hydros = length(ses)

    m[STORED_VOLUME] = @variable(
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
        # (using @variable(..., SDDP.State)), only the 'out' half receives the bound information
        set_lower_bound(m[STORED_VOLUME][n].out, ses.entities[n].min_storage)
        set_upper_bound(m[STORED_VOLUME][n].out, ses.entities[n].max_storage)
    end

    m[INFLOW] = @variable(m, [1:num_hydros], base_name = String(INFLOW))

    m[TURBINED_FLOW] = @variable(m, [1:num_hydros], base_name = String(TURBINED_FLOW))
    set_lower_bound.(m[TURBINED_FLOW], 0)
    
    m[SPILLAGE] = @variable(m, [n = 1:num_hydros], base_name = String(SPILLAGE))
    set_lower_bound.(m[SPILLAGE], 0)

    m[OUTFLOW] = @variable(m, [1:num_hydros], base_name = String(OUTFLOW))

    @constraint(m, m[OUTFLOW] .== m[TURBINED_FLOW] + m[SPILLAGE])

    m[HYDRO_GENERATION] = @variable(
        m, [n = 1:num_hydros], base_name = String(HYDRO_GENERATION)
    )
    for n in 1:num_hydros
        set_lower_bound.(m[HYDRO_GENERATION][n], ses.entities[n].min_generation)
        set_upper_bound.(m[HYDRO_GENERATION][n], ses.entities[n].max_generation)
    end

    @constraint(
        m,
        [n = 1:num_hydros],
        m[HYDRO_GENERATION][n] == ses.entities[n].productivity * m[TURBINED_FLOW][n]
    )

    m[HYDRO_MIN_GENERATION_SLACK] = @variable(
        m, [n = 1:num_hydros], base_name = String(HYDRO_MIN_GENERATION_SLACK)
    )
    set_lower_bound.(m[HYDRO_MIN_GENERATION_SLACK], 0)

    @constraint(
        m,
        [n = 1:num_hydros],
        m[HYDRO_GENERATION][n] + m[HYDRO_MIN_GENERATION_SLACK][n] >=
            ses.entities[n].min_generation
    )
end

function add_hydro_balance!(m::JuMP.Model, hydros::Hydros)
    num_hydros = length(hydros)

    m[HYDRO_BALANCE] = @constraint(
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

# HELPER METHODS ---------------------------------------------------------------------------

function upstream(id::Integer, hydros::Hydros)
    upstream_ids = inneighbors(hydros.topology, id)
    return length(upstream_ids) == 0 ? nothing : @view hydros.entities[upstream_ids]
end

function downstream(id::Integer, hydros::Hydros)
    downstream_id = outneighbors(hydros.topology, id)
    return length(downstream_id) == 0 ? nothing : @view hydros.entities[downstream_id[1]]
end

function __build_hydro_entities!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    hydros = d["entities"]
    entities = Hydro[]
    valid = true
    for i in eachindex(hydros)
        entity = Hydro(hydros[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_hydro_topology!(d::Dict{String,Any})::Bool
    entities = d["entities"]
    g = DiGraph(length(entities))
    for hydro in entities
        hydro_id = hydro.id
        downstream_id = hydro.downstream_id
        if downstream_id !== 0
            add_edge!(g, hydro_id, downstream_id)
        end
    end
    d["topology"] = g
    return true
end

function __build_hydros!(d::Dict{String,Any}, buses::Buses, e::CompositeException)::Bool
    valid_key_types = __validate_hydros_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    hydros_d = d["hydros"]

    valid_key_types = __validate_hydros_keys_types_before_build!(hydros_d, e)
    if !valid_key_types
        return false
    end

    d["hydros"] = Hydros(hydros_d, buses, e)
    return d["hydros"] !== nothing
end

function __cast_hydros_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "hydros", e)
end