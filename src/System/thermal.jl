# CLASS Thermal -----------------------------------------------------------------------

function Thermal(d::Dict{String,Any}, buses::Buses, e::CompositeException)

    # Build internal objects
    valid_internals = __build_thermal_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_thermal_keys_types!(d, e)

    # Content validation
    bus_ref = valid_keys_types ? __validate_thermal_content!(d, buses, e) : nothing
    valid_content = bus_ref !== nothing

    # Consistency validation
    valid_consistency = valid_content && __validate_thermal_consistency!(d, e)

    return if valid_consistency
        Thermal(
            d["id"],
            d["name"],
            d["bus_id"],
            d["min_generation"],
            d["max_generation"],
            d["cost"],
            bus_ref,
        )
    else
        nothing
    end
end

# CLASS Thermals -----------------------------------------------------------------------

function Thermals(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    # Build internal objects
    valid_internals = __build_thermals_internals_from_dicts!(d, buses, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_thermals_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_thermals_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_thermals_consistency!(d, e)

    return valid_consistency ? Thermals(d["entities"]) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Thermal)::Integer
    return s.id
end

function get_params(s::Thermal)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "bus_id" => s.bus_id,
        "min_generation" => s.min_generation,
        "max_generation" => s.max_generation,
        "cost" => s.cost,
    )
end

function get_ids(ses::Thermals)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Thermals)::Integer
    return length(get_ids(ses))
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, ses::Thermals)
    num_thermals = length(ses)

    mean_max_generation = mean([e.max_generation for e in ses.entities])
    κ_t = 10^round(log10(mean_max_generation))

    κ[THERMAL_GENERATION] = κ_t

    m[THERMAL_GENERATION] = @variable(
        m, [n = 1:num_thermals], base_name = String(THERMAL_GENERATION)
    )
    for n in 1:num_thermals
        set_lower_bound(m[THERMAL_GENERATION][n], ses.entities[n].min_generation / κ_t)
        set_upper_bound(m[THERMAL_GENERATION][n], ses.entities[n].max_generation / κ_t)
    end

    m[THERMAL_GENERATION_COST] = @expression(
        m, [n = 1:num_thermals], ses.entities[n].cost * κ_t * m[THERMAL_GENERATION][n]
    )

    return nothing
end

# HELPERS --------------------------------------------------------------------------

function __build_thermal_entities!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    thermals = d["entities"]
    entities = Thermal[]
    valid = true
    for i in eachindex(thermals)
        entity = Thermal(thermals[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_thermals!(d::Dict{String,Any}, buses::Buses, e::CompositeException)::Bool
    valid_key_types = __validate_thermals_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    thermals_d = d["thermals"]

    valid_key_types = __validate_thermals_keys_types_before_build!(thermals_d, e)
    if !valid_key_types
        return false
    end

    d["thermals"] = Thermals(thermals_d, buses, e)
    return d["thermals"] !== nothing
end

function __cast_thermals_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "thermals", e)
end