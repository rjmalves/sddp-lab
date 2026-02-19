# SCHEMA --------------------------------------------------------------------------------------

const NONCONTROLLABLE_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule(
        "name",
        String;
        constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")],
    ),
    FieldRule("bus_id", Integer),
    FieldRule("max_generation", Real; constraints = [non_negative()]),
    FieldRule("curtailment_cost", Real; constraints = [non_negative()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_noncontrollables_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["noncontrollables"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_noncontrollables_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{NonControllable}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_noncontrollables_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CROSS-ENTITY / CROSS-FIELD VALIDATORS ----------------------------------------------------

function __validate_noncontrollable_bus_id(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d["bus_id"]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("NonControllable $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_noncontrollable_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Ref{Bus},Nothing}
    bus_index = __validate_noncontrollable_bus_id(d, buses, e)
    valid = bus_index !== nothing

    return valid ? Ref(buses.entities[bus_index]) : nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_noncontrollables_unique_ids!(
    nc_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(nc_ids)) == length(nc_ids)
    valid || push!(e, AssertionError("NonControllable ids must be unique"))
    return valid
end

function __validate_noncontrollables_unique_names!(
    nc_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(nc_names)) == length(nc_names)
    valid || push!(e, AssertionError("NonControllable names must be unique"))
    return valid
end

function __validate_noncontrollables_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    nc_ids = [nc.id for nc in d["entities"]]
    nc_names = [nc.name for nc in d["entities"]]
    valid_ids = __validate_noncontrollables_unique_ids!(nc_ids, e)
    valid_names = __validate_noncontrollables_unique_names!(nc_names, e)
    return valid_ids && valid_names
end

# HELPERS -------------------------------------------------------------------------------------

function __build_noncontrollables_internals_from_dicts!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    return __build_noncontrollable_entities!(d, buses, e)
end
