# CLASS EnergyContract -----------------------------------------------------------------------

function EnergyContract(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid = validate_schema!(
        d, ENERGY_CONTRACT_SCHEMA, e; entity_label = "EnergyContract $(get(d, "id", "?"))"
    )

    bus_ref = valid ? __validate_energycontract_content!(d, buses, e) : nothing
    valid_content = bus_ref !== nothing

    return if valid_content
        EnergyContract(
            d["id"],
            d["name"],
            d["bus_id"],
            d["type"],
            d["price_per_mwh"],
            d["limits"]["min_mw"],
            d["limits"]["max_mw"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS EnergyContracts -----------------------------------------------------------------------

function EnergyContracts(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid_internals = __build_energycontracts_internals_from_dicts!(d, buses, e)
    valid_keys_types = valid_internals && __validate_energycontracts_keys_types!(d, e)
    valid_consistency = valid_keys_types && __validate_energycontracts_consistency!(d, e)

    return valid_consistency ? EnergyContracts(d["entities"]) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::EnergyContract)::Integer
    return s.id
end

function get_params(s::EnergyContract)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "type" => s.contract_type,
        "price_per_mwh" => s.price_per_mwh,
        "min_mw" => s.min_mw,
        "max_mw" => s.max_mw,
    )
end

function get_ids(ses::EnergyContracts)::Vector{Integer}
    return [get_id(ec) for ec in ses.entities]
end

function length(ses::EnergyContracts)::Integer
    return length(get_ids(ses))
end

# HELPERS --------------------------------------------------------------------------

function __build_energycontract_entities!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    energycontracts = d["entities"]
    entities = EnergyContract[]
    valid = true
    for i in eachindex(energycontracts)
        entity = EnergyContract(energycontracts[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_energycontracts!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    valid_key_types = __validate_energycontracts_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    energycontracts_d = d["energycontracts"]

    valid_key_types = __validate_energycontracts_keys_types_before_build!(energycontracts_d, e)
    if !valid_key_types
        return false
    end

    d["energycontracts"] = EnergyContracts(energycontracts_d, buses, e)
    return d["energycontracts"] !== nothing
end

function __cast_energycontracts_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "energycontracts", e)
end
