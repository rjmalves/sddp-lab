# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_thermal_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(
        d, ["id", "name", "bus_id", "min_generation", "max_generation", "cost"], e
    )
    valid_types = __validate_key_types!(
        d,
        ["id", "name", "bus_id", "min_generation", "max_generation", "cost"],
        [Integer, String, Integer, Real, Real, Real],
        e,
    )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_thermal_id(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    valid = id > 0
    valid || push!(e, AssertionError("Thermal id ($id) must be positive"))
    return valid
end

function __validate_thermal_name(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    name = d["name"]
    valid_length = length(name) > 0
    valid_regex = __valid_name_regex_match(name)
    valid = valid_length && valid_regex
    valid_length || push!(
        e, AssertionError("Thermal $id - name ($name) must have at least one character")
    )
    valid_regex || push!(
        e,
        AssertionError(
            "Thermal $id - name ($name) must contain alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return valid
end

function __validate_thermal_bus_id(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d["bus_id"]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("Thermal $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_thermal_cost(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    cost = d["cost"]
    valid = cost >= 0
    valid || push!(e, AssertionError("Thermal $id - cost ($cost) must be non-negative"))
    return valid
end

function __validate_thermal_generation(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    min_generation = d["min_generation"]
    max_generation = d["max_generation"]
    valid = true
    for (generation, var_name) in
        zip([min_generation, max_generation], ["min_generation", "max_generation"])
        valid_generation = generation >= 0
        valid = valid & valid_generation
        valid_generation || push!(
            e,
            AssertionError("Thermal $id - $var_name ($generation) must be non-negative"),
        )
    end
    valid_min_max_generation = min_generation <= max_generation
    valid_min_max_generation || push!(
        e,
        AssertionError(
            "Thermal $id - max_generation ($max_generation) must be >= min_generation ($min_generation)",
        ),
    )
    return valid && valid_min_max_generation
end

function __validate_thermal_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Ref{Bus},Nothing}
    valid_id = __validate_thermal_id(d, e)
    valid_name = __validate_thermal_name(d, e)
    bus_index = __validate_thermal_bus_id(d, buses, e)
    valid_generation = __validate_thermal_generation(d, e)
    valid_cost = __validate_thermal_cost(d, e)
    valid = all([valid_id, valid_name, bus_index !== nothing, valid_generation, valid_cost])

    return valid ? Ref(buses.entities[bus_index]) : nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_thermals_unique_ids!(
    thermal_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(thermal_ids)) == length(thermal_ids)
    valid || push!(e, AssertionError("Thermal ids must be unique"))
    return valid
end

function __validate_thermals_unique_names!(
    thermal_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(thermal_names)) == length(thermal_names)
    valid || push!(e, AssertionError("Thermal names must be unique"))
    return valid
end

function __validate_thermals_consistency!(
    thermal_ids::Vector{<:Integer}, thermal_names::Vector{String}, e::CompositeException
)::Bool
    valid_ids = __validate_thermals_unique_ids!(thermal_ids, e)
    valid_names = __validate_thermals_unique_names!(thermal_names, e)
    return valid_ids && valid_names
end