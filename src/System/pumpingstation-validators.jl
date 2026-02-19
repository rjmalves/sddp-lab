# SCHEMA --------------------------------------------------------------------------------------

const PUMPING_STATION_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule(
        "name",
        String;
        constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")],
    ),
    FieldRule("bus_id", Integer),
    FieldRule("source_hydro_id", Integer),
    FieldRule("destination_hydro_id", Integer),
    FieldRule("consumption_mw_per_m3s", Real; constraints = [positive()]),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_pumpingstations_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["pumpingstations"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_pumpingstations_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{PumpingStation}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_pumpingstations_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CROSS-ENTITY / CROSS-FIELD VALIDATORS ----------------------------------------------------

function __validate_pumpingstation_bus_id(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d["bus_id"]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("PumpingStation $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_pumpingstation_hydro_ids!(
    d::Dict{String,Any}, hydros::Hydros, e::CompositeException
)::Bool
    id = d["id"]
    source_id = d["source_hydro_id"]
    dest_id = d["destination_hydro_id"]
    hydro_ids = get_ids(hydros)

    valid = true

    source_index = findfirst(==(source_id), hydro_ids)
    if source_index === nothing
        push!(e, AssertionError("PumpingStation $id - source_hydro_id ($source_id) not found in hydros"))
        valid = false
    end

    dest_index = findfirst(==(dest_id), hydro_ids)
    if dest_index === nothing
        push!(e, AssertionError("PumpingStation $id - destination_hydro_id ($dest_id) not found in hydros"))
        valid = false
    end

    if valid && source_id == dest_id
        push!(e, AssertionError("PumpingStation $id - source_hydro_id and destination_hydro_id must be different (both are $source_id)"))
        valid = false
    end

    return valid
end

function __validate_pumpingstation_flow!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    id = d["id"]
    if !haskey(d, "flow")
        push!(e, AssertionError("PumpingStation $id - missing required key: flow"))
        return false
    end
    flow = d["flow"]
    if !(flow isa Dict)
        push!(e, AssertionError("PumpingStation $id - flow must be a Dict"))
        return false
    end
    valid = true
    if !haskey(flow, "min_m3s")
        push!(e, AssertionError("PumpingStation $id - flow missing required key: min_m3s"))
        valid = false
    end
    if !haskey(flow, "max_m3s")
        push!(e, AssertionError("PumpingStation $id - flow missing required key: max_m3s"))
        valid = false
    end
    if !valid
        return false
    end
    min_m3s = flow["min_m3s"]
    max_m3s = flow["max_m3s"]
    if !(min_m3s isa Real)
        push!(e, AssertionError("PumpingStation $id - flow.min_m3s must be Real"))
        return false
    end
    if !(max_m3s isa Real)
        push!(e, AssertionError("PumpingStation $id - flow.max_m3s must be Real"))
        return false
    end
    if min_m3s < 0
        push!(e, AssertionError("PumpingStation $id - flow.min_m3s must be non-negative, got $min_m3s"))
        valid = false
    end
    if max_m3s < 0
        push!(e, AssertionError("PumpingStation $id - flow.max_m3s must be non-negative, got $max_m3s"))
        valid = false
    end
    if valid && min_m3s > max_m3s
        push!(
            e,
            AssertionError(
                "PumpingStation $id - flow.min_m3s ($min_m3s) must be <= flow.max_m3s ($max_m3s)"
            ),
        )
        valid = false
    end
    return valid
end

function __validate_pumpingstation_content!(
    d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException
)::Union{Ref{Bus},Nothing}
    bus_index = __validate_pumpingstation_bus_id(d, buses, e)
    valid_hydros = __validate_pumpingstation_hydro_ids!(d, hydros, e)
    valid_flow = __validate_pumpingstation_flow!(d, e)
    valid = bus_index !== nothing && valid_hydros && valid_flow

    return valid ? Ref(buses.entities[bus_index]) : nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_pumpingstations_unique_ids!(
    ps_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(ps_ids)) == length(ps_ids)
    valid || push!(e, AssertionError("PumpingStation ids must be unique"))
    return valid
end

function __validate_pumpingstations_unique_names!(
    ps_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(ps_names)) == length(ps_names)
    valid || push!(e, AssertionError("PumpingStation names must be unique"))
    return valid
end

function __validate_pumpingstations_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    ps_ids = [ps.id for ps in d["entities"]]
    ps_names = [ps.name for ps in d["entities"]]
    valid_ids = __validate_pumpingstations_unique_ids!(ps_ids, e)
    valid_names = __validate_pumpingstations_unique_names!(ps_names, e)
    return valid_ids && valid_names
end

# HELPERS -------------------------------------------------------------------------------------

function __build_pumpingstations_internals_from_dicts!(
    d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException
)::Bool
    return __build_pumpingstation_entities!(d, buses, hydros, e)
end
