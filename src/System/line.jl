# CLASS Line -----------------------------------------------------------------------

struct Line <: SystemEntity
    id::Integer
    name::String
    source_bus_id::Integer
    target_bus_id::Integer
    capacity::Real
    exchange_penalty::Real
    # References to other system elements
    source_bus::Ref{Bus}
    target_bus::Ref{Bus}
end

function Line(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid_keys_types = __validate_line_keys_types!(d, e)
    bus_refs = valid_keys_types ? __validate_line_content!(d, buses, e) : nothing
    valid_content = bus_refs !== nothing
    valid = valid_keys_types && valid_content

    return if valid
        Line(
            d["id"],
            d["name"],
            d["source_bus_id"],
            d["target_bus_id"],
            d["capacity"],
            d["exchange_penalty"],
            bus_refs[:source],
            bus_refs[:target],
        )
    else
        nothing
    end
end

# CLASS Lines -----------------------------------------------------------------------
struct Lines <: SystemEntitySet
    entities::Vector{Line}
end

function Lines(d::Vector{Dict{String,Any}}, buses::Buses, e::CompositeException)
    # Constructs each Line
    entities = Line[]
    for i in 1:length(d)
        entity = Line(d[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
    end

    # Consistency validation
    valid = __validate_lines_consistency!(
        [line.id for line in entities], [line.name for line in entities], e
    )

    return valid ? Lines(entities) : Lines([])
end

# SDDP METHODS -----------------------------------------------------------------------------

# TODO
function add_system_elements!(m::JuMP.Model, ses::Lines) end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Bus)::Integer
    return s.id
end

function get_params(s::Line)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "source_bus_id" => s.source_bus_id,
        "target_bus_id" => s.target_bus_id,
        "capacity" => s.capacity,
        "exchange_penalty" => s.exchange_penalty,
    )
end

function get_ids(ses::Lines)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Lines)::Integer
    return length(get_ids(ses))
end
