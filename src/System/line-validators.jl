# SCHEMA --------------------------------------------------------------------------------------

const LINE_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
    FieldRule("source_bus_id", Integer),
    FieldRule("target_bus_id", Integer),
    FieldRule("capacity", Real; constraints = [positive()]),
    FieldRule("exchange_penalty", Real),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_lines_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["lines"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_lines_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["entities"]
    keys_types = [Vector{Line}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_lines_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CROSS-ENTITY VALIDATORS ------------------------------------------------------------------

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

function __validate_line_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Dict{Symbol,Ref{Bus}},Nothing}
    source_bus_index = __validate_line_bus!(d, "source_bus_id", buses, e)
    target_bus_index = __validate_line_bus!(d, "target_bus_id", buses, e)
    valid = source_bus_index !== nothing && target_bus_index !== nothing
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

function __validate_lines_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    line_ids = [line.id for line in d["entities"]]
    line_names = [line.name for line in d["entities"]]
    valid_ids = __validate_lines_unique_ids!(line_ids, e)
    valid_names = __validate_lines_unique_names!(line_names, e)
    return valid_ids && valid_names
end

# HELPERS -------------------------------------------------------------------------------------

function __build_lines_internals_from_dicts!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    return __build_line_entities!(d, buses, e)
end
