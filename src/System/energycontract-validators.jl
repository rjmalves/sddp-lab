# SCHEMA --------------------------------------------------------------------------------------

const ENERGY_CONTRACT_SCHEMA = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("name", String; constraints = [non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")]),
    FieldRule("bus_id", Integer),
    FieldRule("type", String),
    FieldRule("price_per_mwh", Real),
]

# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_energycontracts_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["energycontracts"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_energycontracts_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{EnergyContract}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_energycontracts_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["entities"]
    keys_types = [Vector{Dict{String,Any}}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CROSS-ENTITY / CROSS-FIELD VALIDATORS ----------------------------------------------------

function __validate_energycontract_bus_id(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Integer,Nothing}
    id = d["id"]
    bus_id = d["bus_id"]
    existing_bus_ids = get_ids(buses)
    bus_index = findfirst(==(bus_id), existing_bus_ids)
    bus_index !== nothing ||
        push!(e, AssertionError("EnergyContract $id - bus_id ($bus_id) not found in buses"))
    return bus_index
end

function __validate_energycontract_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    contract_type = d["type"]
    valid = contract_type in ["import", "export"]
    valid || push!(
        e,
        AssertionError(
            "EnergyContract $id - type must be \"import\" or \"export\", got \"$contract_type\"",
        ),
    )
    return valid
end

function __validate_energycontract_limits!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    if !haskey(d, "limits")
        push!(e, AssertionError("EnergyContract $id - missing required key: limits"))
        return false
    end
    limits = d["limits"]
    if !(limits isa Dict)
        push!(e, AssertionError("EnergyContract $id - limits must be a Dict"))
        return false
    end
    valid = true
    if !haskey(limits, "min_mw")
        push!(e, AssertionError("EnergyContract $id - limits missing required key: min_mw"))
        valid = false
    end
    if !haskey(limits, "max_mw")
        push!(e, AssertionError("EnergyContract $id - limits missing required key: max_mw"))
        valid = false
    end
    if !valid
        return false
    end
    min_mw = limits["min_mw"]
    max_mw = limits["max_mw"]
    if !(min_mw isa Real)
        push!(e, AssertionError("EnergyContract $id - limits.min_mw must be Real"))
        return false
    end
    if !(max_mw isa Real)
        push!(e, AssertionError("EnergyContract $id - limits.max_mw must be Real"))
        return false
    end
    if min_mw < 0
        push!(
            e,
            AssertionError(
                "EnergyContract $id - limits.min_mw must be non-negative, got $min_mw"
            ),
        )
        valid = false
    end
    if max_mw < 0
        push!(
            e,
            AssertionError(
                "EnergyContract $id - limits.max_mw must be non-negative, got $max_mw"
            ),
        )
        valid = false
    end
    if valid && min_mw > max_mw
        push!(
            e,
            AssertionError(
                "EnergyContract $id - limits.min_mw ($min_mw) must be <= limits.max_mw ($max_mw)",
            ),
        )
        valid = false
    end
    return valid
end

function __validate_energycontract_content!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Union{Ref{Bus},Nothing}
    bus_index = __validate_energycontract_bus_id(d, buses, e)
    valid_type = __validate_energycontract_type!(d, e)
    valid_limits = __validate_energycontract_limits!(d, e)
    valid = bus_index !== nothing && valid_type && valid_limits

    return valid ? Ref(buses.entities[bus_index]) : nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_energycontracts_unique_ids!(
    ec_ids::Vector{<:Integer}, e::CompositeException
)::Bool
    valid = length(unique(ec_ids)) == length(ec_ids)
    valid || push!(e, AssertionError("EnergyContract ids must be unique"))
    return valid
end

function __validate_energycontracts_unique_names!(
    ec_names::Vector{String}, e::CompositeException
)::Bool
    valid = length(unique(ec_names)) == length(ec_names)
    valid || push!(e, AssertionError("EnergyContract names must be unique"))
    return valid
end

function __validate_energycontracts_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    ec_ids = [ec.id for ec in d["entities"]]
    ec_names = [ec.name for ec in d["entities"]]
    valid_ids = __validate_energycontracts_unique_ids!(ec_ids, e)
    valid_names = __validate_energycontracts_unique_names!(ec_names, e)
    return valid_ids && valid_names
end

# HELPERS -------------------------------------------------------------------------------------

function __build_energycontracts_internals_from_dicts!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    return __build_energycontract_entities!(d, buses, e)
end
