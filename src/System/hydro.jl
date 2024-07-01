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

    @variable(
        m,
        ses.entities[n].min_storage <=
            earm[n = 1:num_hydros] <=
            ses.entities[n].max_storage,
        SDDP.State,
        initial_value = ses.entities[n].initial_storage
    )

    @variables(
        m,
        begin
            ses.entities[n].min_generation <=
            gh[n = 1:num_hydros] <=
            ses.entities[n].max_generation
            slack_ghmin[n = 1:num_hydros] >= 0
            vert[n = 1:num_hydros] >= 0
        end
    )

    @variable(m, ena[1:num_hydros])

    @constraint(
        m, [n = 1:num_hydros], gh[n] + slack_ghmin[n] >= ses.entities[n].min_generation
    )

    @constraint(
        m, fim_horizonte[n = 1:num_hydros], earm[n].out >= ses.entities[n].min_storage
    )
end

function __add_hydro_balance!(m::JuMP.Model, hydros::Hydros)
    num_hydros = length(hydros)

    @constraint(
        m,
        balanco_hidrico[n = 1:num_hydros],
        m[:earm][n].out ==
            m[:earm][n].in - m[:gh][n] - m[:vert][n] +
        m[:ena][n] +
        sum(
            m[:gh][j] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
        ) +
        sum(
            m[:vert][j] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n]
        )
    )
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