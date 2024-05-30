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

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_buses_unique_ids!(buses::Vector{Bus}, e::CompositeException)
    ids = [b.id for b in buses]
    length(unique(ids)) == length(ids) || push!(e, AssertionError("Bus ids must be unique"))
    return nothing
end

function __validate_buses_unique_names!(buses::Vector{Bus}, e::CompositeException)
    names = [b.name for b in buses]
    length(unique(names)) == length(names) ||
        push!(e, AssertionError("Bus names must be unique"))
    return nothing
end