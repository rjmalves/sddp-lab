# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_line_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(
        d,
        ["id", "name", "source_bus_id", "target_bus_id", "capacity", "exchange_penalty"],
        e,
    )
    valid_types = __validate_key_types!(
        d,
        ["id", "name", "source_bus_id", "target_bus_id", "capacity", "exchange_penalty"],
        [Integer, String, Integer, Integer, Real, Real],
        e,
    )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_line_id!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid = d["id"] > 0
    valid || push!(e, AssertionError("Line id ($id) must be positive"))
    return valid
end

function __validate_line_name!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    name = d["name"]
    valid_length = length(name) > 0
    valid_regex = __valid_name_regex_match(name)
    valid = valid_length && valid_regex
    valid_length ||
        push!(e, AssertionError("Line $id - name ($name) must have at least one character"))
    valid_regex || push!(
        e,
        AssertionError(
            "Line $id - name ($name) must contain alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return valid
end

function __validate_line_bus!(
    d::Dict{String,Any}, key::String, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d[key]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("Line $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_line_capacity!(d::Dict{String,Any}, e::CompositeException)::Bool
    capacity = d["capacity"]
    valid = capacity > 0
    valid || push!(e, AssertionError("Line capacity ($capacity) must be positive"))
    return valid
end

function __validate_line_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Dict{Symbol,Ref{Bus}}
    valid_id = __validate_line_id!(d, e)
    valid_name = __validate_line_name!(d, e)
    source_bus_index = __validate_line_bus!(d, "source_bus_id", buses, e)
    target_bus_index = __validate_line_bus!(d, "target_bus_id", buses, e)
    valid_capacity = __validate_line_capacity!(d, e)
    valid = all([
        valid_id,
        valid_name,
        source_bus_index !== nothing,
        target_bus_index !== nothing,
        valid_capacity,
    ])
    return if valid
        Dict{Symbol,Ref{Bus}}(
            :source => Ref(buses.entities[source_bus_index]),
            :target => Ref(buses.entities[target_bus_index]),
        )
    else
        nothing
    end
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_lines_unique_ids!(
    line_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(line_ids)) == length(line_ids)
    valid || push!(e, AssertionError("Line ids must be unique"))
    return valid
end

function __validate_lines_unique_names!(
    line_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(line_names)) == length(line_names)
    valid || push!(e, AssertionError("Line names must be unique"))
    return valid
end

function __validate_lines_consistency!(
    line_ids::Vector{<:Integer}, line_names::Vector{String}, e::CompositeException
)::Bool
    valid_ids = __validate_lines_unique_ids!(line_ids, e)
    valid_names = __validate_lines_unique_names!(line_names, e)
    return valid_ids && valid_names
end
