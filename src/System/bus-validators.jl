# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_bus_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["id", "name", "deficit_cost"]
    keys_types = [Integer, String, Real]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_bus_id!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    valid = id > 0
    valid || push!(e, AssertionError("Bus id ($id) must be positive"))
    return valid
end

function __validate_bus_name!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    name = d["name"]
    valid_length = length(name) > 0
    valid_regex = __valid_name_regex_match(name)
    valid = valid_length && valid_regex
    valid_length ||
        push!(e, AssertionError("Bus $id - name ($name) must have at least one character"))
    valid_regex || push!(
        e,
        AssertionError(
            "Bus $id - name ($name) must contain alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return valid
end

function __validate_bus_deficit_cost!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    deficit_cost = d["deficit_cost"]
    valid = deficit_cost > 0
    valid ||
        push!(e, AssertionError("Bus $id - deficit_cost ($deficit_cost) must be positive"))
    return valid
end

function __validate_bus_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_id = __validate_bus_id!(d, e)
    valid_name = __validate_bus_name!(d, e)
    valid_deficit_cost = __validate_bus_deficit_cost!(d, e)
    return valid_id && valid_name && valid_deficit_cost
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_buses_unique_ids!(
    bus_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(bus_ids)) == length(bus_ids)
    valid || push!(e, AssertionError("Bus ids must be unique"))
    return valid
end

function __validate_buses_unique_names!(
    bus_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(bus_names)) == length(bus_names)
    valid || push!(e, AssertionError("Bus names must be unique"))
    return valid
end

function __validate_buses_consistency!(
    bus_ids::Vector{<:Integer}, bus_names::Vector{String}, e::CompositeException
)::Bool
    valid_ids = __validate_buses_unique_ids!(bus_ids, e)
    valid_names = __validate_buses_unique_names!(bus_names, e)
    return valid_ids && valid_names
end
