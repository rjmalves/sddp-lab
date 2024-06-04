# CLASS Bus -----------------------------------------------------------------------

struct Bus <: SystemEntity
    id::Integer
    name::String
    deficit_cost::Real
end

function Bus(d::Dict{String,Any}; e::CompositeException = CompositeException())
    __validate_bus_keys_types!(d, e)
    __validate_bus_content!(d, e)

    return Bus(d["id"], d["name"], d["deficit_cost"])
end

# CLASS Buses -----------------------------------------------------------------------

struct Buses <: SystemEntitySet
    entities::Vector{Bus}
end

function Buses(d::Vector{Dict{String,Any}}; e::CompositeException = CompositeException())
    # Constructs each Bus
    entities = Bus[]
    for i in 1:length(d)
        push!(entities, Bus(d[i]; e = e))
    end

    # Consistency validation
    __validate_buses_consistency!(
        [bus.id for bus in entities], [bus.name for bus in entities], e
    )

    return Buses(entities)
end

# SDDP METHODS -----------------------------------------------------------------------------

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

function length(ses::Buses)
    return length(get_ids(ses))
end