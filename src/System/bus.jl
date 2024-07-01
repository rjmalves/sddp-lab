# CLASS Bus -----------------------------------------------------------------------

function Bus(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_bus_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_bus_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_bus_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_bus_consistency!(d, e)

    return valid_consistency ? Bus(d["id"], d["name"], d["deficit_cost"]) : nothing
end

# CLASS Buses -----------------------------------------------------------------------

function Buses(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_buses_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_buses_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_buses_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_buses_consistency!(d, e)

    return valid_consistency ? Buses(d["entities"]) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, ses::Buses)
    num_buses = length(ses)

    @variable(m, load[1:num_buses])
    @variable(m, deficit[1:num_buses] >= 0)
end

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

# HELPERS --------------------------------------------------------------------------

function __build_bus_entities!(d::Dict{String,Any}, e::CompositeException)::Bool
    buses = d["entities"]
    entities = Bus[]
    valid = true
    for i in eachindex(buses)
        entity = Bus(buses[i], e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_buses!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_buses_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    buses_d = d["buses"]

    valid_key_types = __validate_buses_keys_types_before_build!(buses_d, e)
    if !valid_key_types
        return false
    end

    d["buses"] = Buses(buses_d, e)
    return d["buses"] !== nothing
end

function __cast_buses_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "buses", e)
end