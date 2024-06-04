# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_bus_keys_types!(d::Dict{String,Any}, e::CompositeException)
    __validate_keys!(d, ["id", "name", "deficit_cost"], e)
    __validate_key_types!(d, ["id", "name", "deficit_cost"], [Integer, String, Real], e)
    return __throw_composite_exception_if_any(e)
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_bus_id!(id::Integer, e::CompositeException)
    id > 0 || push!(e, AssertionError("Bus id ($id) must be positive"))
    return nothing
end

function __validate_bus_name!(name::String, e::CompositeException)
    length(name) > 0 ||
        push!(e, AssertionError("Bus name ($name) must have at least one character"))
    __valid_name_regex_match(name) || push!(
        e,
        AssertionError(
            "Bus name ($name) must contain only alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return nothing
end

function __validate_bus_deficit_cost!(deficit_cost::Real, e::CompositeException)
    deficit_cost > 0 ||
        push!(e, AssertionError("Bus deficit_cost ($deficit_cost) must be positive"))
    return nothing
end

function __validate_bus_content!(d::Dict{String,Any}, e::CompositeException)
    __validate_bus_id!(d["id"], e)
    __validate_bus_name!(d["name"], e)
    __validate_bus_deficit_cost!(d["deficit_cost"], e)
    return __throw_composite_exception_if_any(e)
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_buses_unique_ids!(bus_ids::Vector{<:Integer}, e::CompositeException)
    length(unique(bus_ids)) == length(bus_ids) ||
        push!(e, AssertionError("Bus ids must be unique"))
    return nothing
end

function __validate_buses_unique_names!(bus_names::Vector{String}, e::CompositeException)
    length(unique(bus_names)) == length(bus_names) ||
        push!(e, AssertionError("Bus names must be unique"))
    return nothing
end

function __validate_buses_consistency!(
    bus_ids::Vector{<:Integer}, bus_names::Vector{String}, e::CompositeException
)
    __validate_buses_unique_ids!(bus_ids, e)
    __validate_buses_unique_names!(bus_names, e)
    return __throw_composite_exception_if_any(e)
end
