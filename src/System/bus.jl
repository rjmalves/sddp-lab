# CLASS Bus -----------------------------------------------------------------------

struct Bus <: SystemEntity
    id::Integer
    name::String
    deficit_cost::Real
end

function Bus(d::Dict{String,Any})
    # Key and type validation
    e = CompositeException()
    __validate_keys!(d, ["id", "name", "deficit_cost"], e)
    __validate_key_types!(d, ["id", "name", "deficit_cost"], [Integer, String, Real], e)
    throw_composite_exception_if_any(e)

    # Content validation
    __validate_bus_id!(d["id"], e)
    __validate_bus_name!(d["name"], e)
    __validate_bus_deficit_cost!(d["deficit_cost"], e)
    throw_composite_exception_if_any(e)

    return Bus(d["id"], d["name"], d["deficit_cost"])
end

# CLASS Buses -----------------------------------------------------------------------

struct Buses <: SystemEntitySet
    entities::Vector{Bus}
end

function Buses(d::Vector{Dict{String,Any}})
    # Constructs each Bus
    entities = Bus[]
    for i in 1:length(d)
        push!(entities, Bus(d[i]))
    end

    # Consistency validation
    e = CompositeException()
    __validate_buses_unique_ids!(entities, e)
    __validate_buses_unique_names!(entities, e)
    throw_composite_exception_if_any(e)

    return Buses(entities)
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Bus)
    return s.id
end

function get_params(s::Bus)
    return Dict{String,Any}(
        "id" => s.id, "name" => s.name, "deficit_cost" => s.deficit_cost
    )
end

function get_ids(ses::Buses)
    return [get_id(b) for b in ses.entities]
end
