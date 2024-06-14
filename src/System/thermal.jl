# CLASS Thermal -----------------------------------------------------------------------

struct Thermal <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    min_generation::Real
    max_generation::Real
    cost::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

function Thermal(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid_keys_types = __validate_thermal_keys_types!(d, e)
    bus_ref = __validate_thermal_content!(d, buses, e)
    valid_content = bus_ref !== nothing
    valid = valid_keys_types && valid_content

    return if valid
        Thermal(
            d["id"],
            d["name"],
            d["bus_id"],
            d["min_generation"],
            d["max_generation"],
            d["cost"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS Thermals -----------------------------------------------------------------------

struct Thermals <: SystemEntitySet
    entities::Vector{Thermal}
end

function Thermals(d::Vector{Dict{String,Any}}, buses::Buses, e::CompositeException)
    # Constructs each Thermal
    entities = Thermal[]
    for i in 1:length(d)
        entity = Thermal(d[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
    end

    # Consistency validation
    valid = __validate_thermals_consistency!(
        [thermal.id for thermal in entities], [thermal.name for thermal in entities], e
    )

    return valid ? Thermals(entities) : Thermals([])
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Thermal)::Integer
    return s.id
end

function get_params(s::Thermal)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "min_generation" => s.min_generation,
        "max_generation" => s.max_generation,
        "cost" => s.cost,
    )
end

function get_ids(ses::Thermals)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Thermals)::Integer
    return length(get_ids(ses))
end

# SDDP METHODS -----------------------------------------------------------------------------

# TODO
function add_system_elements!(m::JuMP.Model, ses::Thermals) end
