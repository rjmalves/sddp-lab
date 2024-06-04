# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_hydro_keys_types!(d::Dict{String,Any}, e::CompositeException)
    __validate_keys!(
        d,
        [
            "id",
            "downstream_id",
            "name",
            "bus_id",
            "productivity",
            "initial_storage",
            "min_storage",
            "max_storage",
            "min_generation",
            "max_generation",
            "spillage_penalty",
        ],
        e,
    )
    __validate_key_types!(
        d,
        [
            "id",
            "downstream_id",
            "name",
            "bus_id",
            "productivity",
            "initial_storage",
            "min_storage",
            "max_storage",
            "min_generation",
            "max_generation",
            "spillage_penalty",
        ],
        [Integer, Integer, String, Integer, Real, Real, Real, Real, Real, Real, Real],
        e,
    )
    return __throw_composite_exception_if_any(e)
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_hydro_id(id::Integer, e::CompositeException)
    id > 0 || push!(e, AssertionError("Hydro id ($id) must be positive"))
    return nothing
end

function __validate_hydro_downstream_id(downstream_id::Integer, e::CompositeException)
    downstream_id >= 0 || push!(
        e, AssertionError("Hydro downstream_id ($downstream_id) must be non-negative")
    )
    return nothing
end

function __validate_hydro_name(name::String, e::CompositeException)
    length(name) > 0 ||
        push!(e, AssertionError("Hydro name ($name) must have at least one character"))
    __valid_name_regex_match(name) || push!(
        e,
        AssertionError(
            "Hydro name ($name) must contain only alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return nothing
end

function __validate_hydro_bus_id(bus_id::Integer, buses::Buses, e::CompositeException)
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("Hydro bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_hydro_productivity(productivity::Real, e::CompositeException)
    productivity > 0 ||
        push!(e, AssertionError("Hydro productivity ($productivity) must be non-negative"))
    return nothing
end

function __validate_hydro_storage(
    initial_storage::Real, min_storage::Real, max_storage::Real, e::CompositeException
)
    for (storage, var_name) in zip(
        [initial_storage, min_storage, max_storage],
        ["initial_storage", "min_storage", "max_storage"],
    )
        storage >= 0 ||
            push!(e, AssertionError("Hydro $var_name ($storage) must be non-negative"))
    end
    min_storage <= max_storage || push!(
        e,
        AssertionError(
            "Hydro max_storage ($max_storage) must be >= min_storage ($min_storage)"
        ),
    )
    min_storage <= initial_storage <= max_storage || push!(
        e,
        AssertionError(
            "Hydro initial_storage ($initial_storage) not in [$min_storage, $max_storage]",
        ),
    )
    return nothing
end

function __validate_hydro_generation(
    min_generation::Real, max_generation::Real, e::CompositeException
)
    for (generation, var_name) in
        zip([min_generation, max_generation], ["min_generation", "max_generation"])
        generation >= 0 ||
            push!(e, AssertionError("Hydro $var_name ($generation) must be non-negative"))
    end
    min_generation <= max_generation || push!(
        e,
        AssertionError(
            "Hydro max_generation ($max_generation) must be >= min_generation ($min_generation)",
        ),
    )
    return nothing
end

function __validate_hydro_spillage_penalty(spillage_penalty::Real, e::CompositeException)
    spillage_penalty >= 0 || push!(
        e,
        AssertionError("Hydro spillage_penalty ($spillage_penalty) must be non-negative"),
    )
    return nothing
end

function __validate_hydro_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Ref{Bus}
    __validate_hydro_id(d["id"], e)
    __validate_hydro_downstream_id(d["downstream_id"], e)
    __validate_hydro_name(d["name"], e)
    bus_index = __validate_hydro_bus_id(d["bus_id"], buses, e)
    __validate_hydro_productivity(d["productivity"], e)
    __validate_hydro_storage(d["initial_storage"], d["min_storage"], d["max_storage"], e)
    __validate_hydro_generation(d["min_generation"], d["max_generation"], e)
    __validate_hydro_spillage_penalty(d["spillage_penalty"], e)
    __throw_composite_exception_if_any(e)
    return Ref(buses.entities[bus_index])
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_hydros_unique_ids!(hydro_ids::Vector{<:Integer}, e::CompositeException)
    length(unique(hydro_ids)) == length(hydro_ids) ||
        push!(e, AssertionError("Hydro ids must be unique"))
    return nothing
end

function __validate_hydros_unique_names!(hydro_names::Vector{String}, e::CompositeException)
    length(unique(hydro_names)) == length(hydro_names) ||
        push!(e, AssertionError("Hydro names must be unique"))
    return nothing
end

function __validate_hydro_topology(topology_graph::DiGraph, e::CompositeException)
    # Check if the graph ia a DAG
    !is_cyclic(topology_graph) || push!(e, AssertionError("Hydro topology must be a DAG"))
    return nothing
end

function __validate_hydros_consistency!(
    hydro_ids::Vector{<:Integer},
    hydro_names::Vector{String},
    topology_graph::DiGraph,
    e::CompositeException,
)
    __validate_hydros_unique_ids!(hydro_ids, e)
    __validate_hydros_unique_names!(hydro_names, e)
    __validate_hydro_topology(topology_graph, e)
    return __throw_composite_exception_if_any(e)
end