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
end

function Hydro(d::Dict{String,Any})

    # Key and type validation
    e = CompositeException()
    __validate_keys!(
        d,
        [
            "id",
            "downstream_id",
            "name",
            "bus_id",
            "productivity",
            "initial_storage",
            "min_storage",
            "max_storage",
            "min_generation",
            "max_generation",
            "spillage_penalty",
        ],
        e,
    )
    __validate_key_types!(
        d,
        [
            "id",
            "downstream_id",
            "name",
            "bus_id",
            "productivity",
            "initial_storage",
            "min_storage",
            "max_storage",
            "min_generation",
            "max_generation",
            "spillage_penalty",
        ],
        [Integer, Integer, String, Integer, Real, Real, Real, Real, Real, Real, Real],
        e,
    )
    throw_composite_exception_if_any(e)

    # Content validation
    __validate_hydro_id(d["id"], e)
    __validate_hydro_downstream_id(d["downstream_id"], e)
    __validate_hydro_name(d["name"], e)
    __validate_hydro_bus_id(d["bus_id"], e)
    __validate_hydro_productivity(d["productivity"], e)
    __validate_hydro_storage(d["initial_storage"], d["min_storage"], d["max_storage"], e)
    __validate_hydro_generation(d["min_generation"], d["max_generation"], e)
    __validate_hydro_spillage_penalty(d["spillage_penalty"], e)
    throw_composite_exception_if_any(e)

    return Hydro(
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
    )
end

# CLASS Hydros -----------------------------------------------------------------------

struct Hydros <: SystemEntitySet
    entities::Vector{Hydro}
end

function Hydros(d::Vector{Dict{String,Any}})
    # Constructs each Hydro
    entities = Hydro[]
    for i in 1:length(d)
        push!(entities, Hydro(d[i]))
    end

    # Consistency validation
    e = CompositeException()
    __validate_hydros_unique_ids!(entities, e)
    __validate_hydros_unique_names!(entities, e)
    throw_composite_exception_if_any(e)

    return Hydros(entities)
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Hydro)
    return s.id
end

function get_params(s::Hydro)
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

function get_ids(ses::Hydros)
    return [get_id(b) for b in ses.entities]
end
