# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_line_keys_types!(d::Dict{String,Any}, e::CompositeException)
    __validate_keys!(
        d,
        ["id", "name", "source_bus_id", "target_bus_id", "capacity", "exchange_penalty"],
        e,
    )
    __validate_key_types!(
        d,
        ["id", "name", "source_bus_id", "target_bus_id", "capacity", "exchange_penalty"],
        [Integer, String, Integer, Integer, Real, Real],
        e,
    )
    return __throw_composite_exception_if_any(e)
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_line_id!(id::Integer, e::CompositeException)
    id > 0 || push!(e, AssertionError("Line id ($id) must be positive"))
    return nothing
end

function __validate_line_name!(name::String, e::CompositeException)
    length(name) > 0 ||
        push!(e, AssertionError("Line name ($name) must have at least one character"))
    __valid_name_regex_match(name) || push!(
        e,
        AssertionError(
            "Line name ($name) must contain only alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return nothing
end

function __validate_line_bus!(bus_id::Integer, buses::Buses, e::CompositeException)
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("Line bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_line_capacity!(capacity::Real, e::CompositeException)
    capacity > 0 || push!(e, AssertionError("Line capacity ($capacity) must be positive"))
    return nothing
end

function __validate_line_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Dict{Symbol,Ref{Bus}}
    __validate_line_id!(d["id"], e)
    __validate_line_name!(d["name"], e)
    source_bus_index = __validate_line_bus!(d["source_bus_id"], buses, e)
    target_bus_index = __validate_line_bus!(d["target_bus_id"], buses, e)
    __validate_line_capacity!(d["capacity"], e)
    __throw_composite_exception_if_any(e)
    return Dict{Symbol,Ref{Bus}}(
        :source => Ref(buses.entities[source_bus_index]),
        :target => Ref(buses.entities[target_bus_index]),
    )
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_lines_unique_ids!(line_ids::Vector{<:Integer}, e::CompositeException)
    length(unique(line_ids)) == length(line_ids) ||
        push!(e, AssertionError("Line ids must be unique"))
    return nothing
end

function __validate_lines_unique_names!(line_names::Vector{String}, e::CompositeException)
    length(unique(line_names)) == length(line_names) ||
        push!(e, AssertionError("Line names must be unique"))
    return nothing
end

function __validate_lines_consistency!(
    line_ids::Vector{<:Integer}, line_names::Vector{String}, e::CompositeException
)
    __validate_lines_unique_ids!(line_ids, e)
    __validate_lines_unique_names!(line_names, e)
    return __throw_composite_exception_if_any(e)
end
