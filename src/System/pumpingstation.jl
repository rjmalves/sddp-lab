# CLASS PumpingStation -----------------------------------------------------------------------

function PumpingStation(d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException)
    valid = validate_schema!(
        d, PUMPING_STATION_SCHEMA, e; entity_label = "PumpingStation $(get(d, "id", "?"))"
    )

    bus_ref = valid ? __validate_pumpingstation_content!(d, buses, hydros, e) : nothing
    valid_content = bus_ref !== nothing

    return if valid_content
        PumpingStation(
            d["id"],
            d["name"],
            d["bus_id"],
            d["source_hydro_id"],
            d["destination_hydro_id"],
            d["consumption_mw_per_m3s"],
            d["flow"]["min_m3s"],
            d["flow"]["max_m3s"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS PumpingStations -----------------------------------------------------------------------

function PumpingStations(d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException)
    valid_internals = __build_pumpingstations_internals_from_dicts!(d, buses, hydros, e)
    valid_keys_types = valid_internals && __validate_pumpingstations_keys_types!(d, e)
    valid_consistency = valid_keys_types && __validate_pumpingstations_consistency!(d, e)

    return valid_consistency ? PumpingStations(d["entities"]) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::PumpingStation)::Integer
    return s.id
end

function get_params(s::PumpingStation)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "source_hydro_id" => s.source_hydro_id,
        "destination_hydro_id" => s.destination_hydro_id,
        "consumption_mw_per_m3s" => s.consumption_mw_per_m3s,
        "min_m3s" => s.min_m3s,
        "max_m3s" => s.max_m3s,
    )
end

function get_ids(ses::PumpingStations)::Vector{Integer}
    return [get_id(ps) for ps in ses.entities]
end

function length(ses::PumpingStations)::Integer
    return length(get_ids(ses))
end

# HELPERS --------------------------------------------------------------------------

function __build_pumpingstation_entities!(
    d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException
)::Bool
    pumpingstations = d["entities"]
    entities = PumpingStation[]
    valid = true
    for i in eachindex(pumpingstations)
        entity = PumpingStation(pumpingstations[i], buses, hydros, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_pumpingstations!(
    d::Dict{String,Any}, buses::Buses, hydros::Hydros, e::CompositeException
)::Bool
    valid_key_types = __validate_pumpingstations_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    pumpingstations_d = d["pumpingstations"]

    valid_key_types = __validate_pumpingstations_keys_types_before_build!(pumpingstations_d, e)
    if !valid_key_types
        return false
    end

    d["pumpingstations"] = PumpingStations(pumpingstations_d, buses, hydros, e)
    return d["pumpingstations"] !== nothing
end

function __cast_pumpingstations_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "pumpingstations", e)
end
