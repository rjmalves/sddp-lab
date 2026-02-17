# SCHEMA --------------------------------------------------------------------------------------

const HYDRO_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("downstream_id", Integer; constraints = [non_negative()]),
    FieldRule(
        "name",
        String;
        constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")],
    ),
    FieldRule("bus_id", Integer),
    FieldRule("productivity", Real; constraints = [non_negative()]),
    FieldRule("initial_storage", Real; constraints = [non_negative()]),
    FieldRule("min_storage", Real; constraints = [non_negative()]),
    FieldRule("max_storage", Real; constraints = [non_negative()]),
    FieldRule("min_generation", Real; constraints = [non_negative()]),
    FieldRule("max_generation", Real; constraints = [non_negative()]),
    FieldRule("spillage_penalty", Real; constraints = [non_negative()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_hydros_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["hydros"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_hydros_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["entities", "topology"]
    keys_types = [Vector{Hydro}, T where {T <: DiGraph{Int64}}]

    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_hydros_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CROSS-ENTITY / CROSS-FIELD VALIDATORS ----------------------------------------------------

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

function __validate_hydro_storage(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    initial_storage = d["initial_storage"]
    min_storage = d["min_storage"]
    max_storage = d["max_storage"]
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
    return valid_min_max_storage && valid_initial_storage
end

function __validate_hydro_generation(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    min_generation = d["min_generation"]
    max_generation = d["max_generation"]
    valid_min_max_generation = min_generation <= max_generation
    valid_min_max_generation || push!(
        e,
        AssertionError(
            "Hydro $id - max_generation ($max_generation) must be >= min_generation ($min_generation)",
        ),
    )
    return valid_min_max_generation
end

function __validate_hydro_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Ref{Bus},Nothing}
    bus_index = __validate_hydro_bus_id(d, buses, e)
    valid_storage = __validate_hydro_storage(d, e)
    valid_generation = __validate_hydro_generation(d, e)
    valid = bus_index !== nothing && valid_storage && valid_generation

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

function __validate_hydros_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    hydro_ids = [hydro.id for hydro in d["entities"]]
    hydro_names = [hydro.name for hydro in d["entities"]]
    topology_graph = d["topology"]
    valid_ids = __validate_hydros_unique_ids!(hydro_ids, e)
    valid_names = __validate_hydros_unique_names!(hydro_names, e)
    valid_topology = __validate_hydro_topology(topology_graph, e)
    return valid_ids && valid_names && valid_topology
end

# HELPERS -------------------------------------------------------------------------------------

function __build_hydros_internals_from_dicts!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    valid_hydros = __build_hydro_entities!(d, buses, e)
    valid_topology = __build_hydro_topology!(d)
    return valid_hydros && valid_topology
end
