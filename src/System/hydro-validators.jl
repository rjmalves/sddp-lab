# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_hydro_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(
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
    valid_types = __validate_key_types!(
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
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_hydro_id(d::Dict{String,Any}, e::CompositeException)::Bool
    valid = d["id"] > 0
    valid || push!(e, AssertionError("Hydro id ($id) must be positive"))
    return valid
end

function __validate_hydro_downstream_id(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    downstream_id = d["downstream_id"]
    valid = downstream_id >= 0
    valid || push!(
        e,
        AssertionError("Hydro $id - downstream_id ($downstream_id) must be non-negative"),
    )
    return valid
end

function __validate_hydro_name(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    name = d["name"]
    valid_length = length(name) > 0
    valid_regex = __valid_name_regex_match(name)
    valid = valid_length && valid_regex
    valid_length || push!(
        e, AssertionError("Hydro $id - name ($name) must have at least one character")
    )
    valid_regex || push!(
        e,
        AssertionError(
            "Hydro $id - name ($name) must contain alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return valid
end

function __validate_hydro_bus_id(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d["bus_id"]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("Hydro $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_hydro_productivity(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    productivity = d["productivity"]
    valid = productivity >= 0
    valid || push!(
        e,
        AssertionError("Hydro $id - productivity ($productivity) must be non-negative"),
    )
    return valid
end

function __validate_hydro_storage(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    initial_storage = d["initial_storage"]
    min_storage = d["min_storage"]
    max_storage = d["max_storage"]
    valid = true
    for (storage, var_name) in zip(
        [initial_storage, min_storage, max_storage],
        ["initial_storage", "min_storage", "max_storage"],
    )
        valid_storage = storage >= 0
        valid = valid & valid_storage
        valid_storage || push!(
            e, AssertionError("Hydro $id - $var_name ($storage) must be non-negative")
        )
    end
    valid_min_max_storage = min_storage <= max_storage
    valid_min_max_storage || push!(
        e,
        AssertionError(
            "Hydro $id - max_storage ($max_storage) must be >= min_storage ($min_storage)",
        ),
    )
    valid_initial_storage = min_storage <= initial_storage <= max_storage
    valid_initial_storage || push!(
        e,
        AssertionError(
            "Hydro $id - initial_storage ($initial_storage) not in [$min_storage, $max_storage]",
        ),
    )
    return valid && valid_min_max_storage && valid_initial_storage
end

function __validate_hydro_generation(d::Dict{String,Any}, e::CompositeException)::Bool
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
            AssertionError("Hydro $id - $var_name ($generation) must be non-negative"),
        )
    end
    valid_min_max_generation = min_generation <= max_generation
    valid_min_max_generation || push!(
        e,
        AssertionError(
            "Hydro $id - max_generation ($max_generation) must be >= min_generation ($min_generation)",
        ),
    )
    return valid && valid_min_max_generation
end

function __validate_hydro_spillage_penalty(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    spillage_penalty = d["spillage_penalty"]
    valid = spillage_penalty >= 0
    valid || push!(
        e,
        AssertionError(
            "Hydro $id - spillage_penalty ($spillage_penalty) must be non-negative"
        ),
    )
    return valid
end

function __validate_hydro_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Ref{Bus},Nothing}
    valid_id = __validate_hydro_id(d, e)
    valid_downstream_id = __validate_hydro_downstream_id(d, e)
    valid_name = __validate_hydro_name(d, e)
    bus_index = __validate_hydro_bus_id(d, buses, e)
    valid_productivity = __validate_hydro_productivity(d, e)
    valid_storage = __validate_hydro_storage(d, e)
    valid_generation = __validate_hydro_generation(d, e)
    valid_spillage_penalty = __validate_hydro_spillage_penalty(d, e)
    valid = all([
        valid_id,
        valid_downstream_id,
        valid_name,
        bus_index !== nothing,
        valid_productivity,
        valid_storage,
        valid_generation,
        valid_spillage_penalty,
    ])

    return valid ? Ref(buses.entities[bus_index]) : nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_hydros_unique_ids!(
    hydro_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(hydro_ids)) == length(hydro_ids)
    valid || push!(e, AssertionError("Hydro ids must be unique"))
    return valid
end

function __validate_hydros_unique_names!(
    hydro_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(hydro_names)) == length(hydro_names)
    valid || push!(e, AssertionError("Hydro names must be unique"))
    return valid
end

function __validate_hydro_topology(topology_graph::DiGraph, e::CompositeException)::Bool
    # Check if the graph is a DAG
    valid = !is_cyclic(topology_graph)
    valid || push!(e, AssertionError("Hydro topology must be a DAG"))
    return valid
end

function __validate_hydros_consistency!(
    hydro_ids::Vector{<:Integer},
    hydro_names::Vector{String},
    topology_graph::DiGraph,
    e::CompositeException,
)::Bool
    valid_ids = __validate_hydros_unique_ids!(hydro_ids, e)
    valid_names = __validate_hydros_unique_names!(hydro_names, e)
    valid_topology = __validate_hydro_topology(topology_graph, e)
    return valid_ids && valid_names && valid_topology
end