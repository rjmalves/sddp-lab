# SCHEMA --------------------------------------------------------------------------------------

const BUS_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule(
        "name",
        String;
        constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")],
    ),
    FieldRule("deficit_cost", Real; constraints = [positive()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_buses_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["buses"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_buses_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["entities"]
    keys_types = [Vector{Bus}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_buses_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
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

function __validate_buses_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    bus_ids = [bus.id for bus in d["entities"]]
    bus_names = [bus.name for bus in d["entities"]]
    valid_ids = __validate_buses_unique_ids!(bus_ids, e)
    valid_names = __validate_buses_unique_names!(bus_names, e)
    return valid_ids && valid_names
end

# HELPERS -------------------------------------------------------------------------------------

function __build_buses_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __build_bus_entities!(d, e)
end
