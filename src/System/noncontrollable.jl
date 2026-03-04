# CLASS NonControllable -----------------------------------------------------------------------

function NonControllable(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid = validate_schema!(
        d, NONCONTROLLABLE_SCHEMA, e; entity_label = "NonControllable $(get(d, "id", "?"))"
    )

    bus_ref = valid ? __validate_noncontrollable_content!(d, buses, e) : nothing
    valid_content = bus_ref !== nothing

    return if valid_content
        NonControllable(
            d["id"],
            d["name"],
            d["bus_id"],
            d["max_generation"],
            d["curtailment_cost"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS NonControllables -----------------------------------------------------------------------

function NonControllables(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    valid_internals = __build_noncontrollables_internals_from_dicts!(d, buses, e)
    valid_keys_types = valid_internals && __validate_noncontrollables_keys_types!(d, e)
    valid_consistency = valid_keys_types && __validate_noncontrollables_consistency!(d, e)

    return valid_consistency ? NonControllables(d["entities"]) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::NonControllable)::Integer
    return s.id
end

function get_params(s::NonControllable)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "max_generation" => s.max_generation,
        "curtailment_cost" => s.curtailment_cost,
    )
end

function get_ids(ses::NonControllables)::Vector{Integer}
    return [get_id(nc) for nc in ses.entities]
end

function length(ses::NonControllables)::Integer
    return length(get_ids(ses))
end

# HELPERS --------------------------------------------------------------------------

function __build_noncontrollable_entities!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    noncontrollables = d["entities"]
    entities = NonControllable[]
    valid = true
    for i in eachindex(noncontrollables)
        entity = NonControllable(noncontrollables[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_noncontrollables!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    valid_key_types = __validate_noncontrollables_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    noncontrollables_d = d["noncontrollables"]

    valid_key_types = __validate_noncontrollables_keys_types_before_build!(
        noncontrollables_d, e
    )
    if !valid_key_types
        return false
    end

    d["noncontrollables"] = NonControllables(noncontrollables_d, buses, e)
    return d["noncontrollables"] !== nothing
end

function __cast_noncontrollables_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "noncontrollables", e)
end
