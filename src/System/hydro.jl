# CLASS Hydro -----------------------------------------------------------------------

struct Hydro <: SystemEntity
    id::Integer
    downstream_id::Integer
    name::String
    bus_id::Integer
    productivity::Real
    initial_storage::Real
    min_storage::Real
    max_storage::Real
    min_generation::Real
    max_generation::Real
    spillage_penalty::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

function Hydro(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid_keys_types = __validate_hydro_keys_types!(d, e)
    bus_ref = valid_keys_types ? __validate_hydro_content!(d, buses, e) : nothing
    valid_content = bus_ref !== nothing
    valid = valid_keys_types && valid_content

    return if valid
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

struct Hydros <: SystemEntitySet
    entities::Vector{Hydro}
    topology::DiGraph
end

function Hydros(d::Vector{Dict{String,Any}}, buses::Buses, e::CompositeException)
    # Constructs each Hydro and the topology graph
    entities = Hydro[]
    for i in 1:length(d)
        entity = Hydro(d[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
    end
    topology_graph = __build_hydro_dag(entities)

    # Consistency validation
    valid = __validate_hydros_consistency!(
        [hydro.id for hydro in entities],
        [hydro.name for hydro in entities],
        topology_graph,
        e,
    )

    return valid ? Hydros(entities, topology_graph) : Hydros([], DiGraph(0))
end

function __build_hydro_dag(entities::Vector{Hydro})::DiGraph
    g = DiGraph(length(entities))
    for hydro in entities
        hydro_id = hydro.id
        downstream_id = hydro.downstream_id
        if downstream_id !== 0
            add_edge!(g, hydro_id, downstream_id)
        end
    end
    return g
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

# TODO
function add_system_elements!(m::JuMP.Model, ses::Hydros) end

# HELPER METHODS ---------------------------------------------------------------------------

function upstream(id::Integer, hydros::Hydros)
    upstream_ids = inneighbors(hydros.topology, id)
    return length(upstream_ids) == 0 ? nothing : @view hydros.entities[upstream_ids]
end

function downstream(id::Integer, hydros::Hydros)
    downstream_id = outneighbors(hydros.topology, id)
    return length(downstream_id) == 0 ? nothing : @view hydros.entities[downstream_id[1]]
end
