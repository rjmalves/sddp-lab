# CLASS Bus -----------------------------------------------------------------------

struct Bus <: SystemEntity
    id::Integer
    name::String
    deficit_cost::Real
end

function Bus(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_bus_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_bus_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? Bus(d["id"], d["name"], d["deficit_cost"]) : nothing
end

# CLASS Buses -----------------------------------------------------------------------

struct Buses <: SystemEntitySet
    entities::Vector{Bus}
end

function Buses(d::Vector{Dict{String,Any}}, e::CompositeException)
    # Constructs each Bus
    entities = Bus[]
    for i in 1:length(d)
        entity = Bus(d[i], e)
        if entity !== nothing
            push!(entities, entity)
        end
    end

    # Consistency validation
    valid = __validate_buses_consistency!(
        [bus.id for bus in entities], [bus.name for bus in entities], e
    )

    return valid ? Buses(entities) : Buses([])
end

# SDDP METHODS -----------------------------------------------------------------------------

# TODO
function add_system_elements!(m::JuMP.Model, ses::Buses) end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Bus)::Integer
    return s.id
end

function get_params(s::Bus)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id, "name" => s.name, "deficit_cost" => s.deficit_cost
    )
end

function get_ids(ses::Buses)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Buses)::Integer
    return length(get_ids(ses))
end