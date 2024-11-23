# CLASS Line -----------------------------------------------------------------------

function Line(d::Dict{String,Any}, buses::Buses, e::CompositeException)

    # Build internal objects
    valid_internals = __build_line_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_line_keys_types!(d, e)

    # Content validation
    bus_refs = valid_keys_types ? __validate_line_content!(d, buses, e) : nothing
    valid_content = bus_refs !== nothing

    # Consistency validation
    valid_consistency = valid_content && __validate_line_consistency!(d, e)

    return if valid_consistency
        Line(
            d["id"],
            d["name"],
            d["source_bus_id"],
            d["target_bus_id"],
            d["capacity"],
            d["exchange_penalty"],
            bus_refs[:source],
            bus_refs[:target],
        )
    else
        nothing
    end
end

# CLASS Lines -----------------------------------------------------------------------

function Lines(d::Dict{String,Any}, buses::Buses, e::CompositeException)
    # Build internal objects
    valid_internals = __build_lines_internals_from_dicts!(d, buses, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_lines_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_lines_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_lines_consistency!(d, e)

    return valid_consistency ? Lines(d["entities"]) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, ses::Lines)
    num_lines = length(ses)

    mean_capacity = mean([e.capacity for e in ses.entities])
    mean_exchange_penalty = mean([e.exchange_penalty for e in ses.entities])
    κ_r = κ_d = 10^round(0.5 * (log10(mean_capacity) + log10(mean_exchange_penalty)))

    κ[DIRECT_EXCHANGE] = κ_d
    κ[REVERSE_EXCHANGE] = κ_r

    m[DIRECT_EXCHANGE] = @variable(
        m, [n = 1:num_lines], base_name = String(DIRECT_EXCHANGE)
    )
    for n in 1:num_lines
        set_lower_bound(m[DIRECT_EXCHANGE][n], 0)
        set_upper_bound(m[DIRECT_EXCHANGE][n], ses.entities[n].capacity / κ_d)
    end

    m[REVERSE_EXCHANGE] = @variable(
        m, [n = 1:num_lines], base_name = String(REVERSE_EXCHANGE)
    )
    for n in 1:num_lines
        set_lower_bound(m[REVERSE_EXCHANGE][n], 0)
        set_upper_bound(m[REVERSE_EXCHANGE][n], ses.entities[n].capacity / κ_r)
    end

    return m[NET_EXCHANGE] = @expression(
        m, κ_d * m[DIRECT_EXCHANGE] - κ_r * m[REVERSE_EXCHANGE]
    )
end

# GENERAL METHODS --------------------------------------------------------------------------

function get_id(s::Line)::Integer
    return s.id
end

function get_params(s::Line)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => s.id,
        "name" => s.name,
        "source_bus_id" => s.source_bus_id,
        "target_bus_id" => s.target_bus_id,
        "capacity" => s.capacity,
        "exchange_penalty" => s.exchange_penalty,
    )
end

function get_ids(ses::Lines)::Vector{Integer}
    return [get_id(b) for b in ses.entities]
end

function length(ses::Lines)::Integer
    return length(get_ids(ses))
end

# HELPERS --------------------------------------------------------------------------

function __build_line_entities!(
    d::Dict{String,Any}, buses::Buses, e::CompositeException
)::Bool
    lines = d["entities"]
    entities = Line[]
    valid = true
    for i in eachindex(lines)
        entity = Line(lines[i], buses, e)
        if entity !== nothing
            push!(entities, entity)
        end
        valid = valid && entity !== nothing
    end
    d["entities"] = entities
    return valid
end

function __build_lines!(d::Dict{String,Any}, buses::Buses, e::CompositeException)::Bool
    valid_key_types = __validate_lines_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    lines_d = d["lines"]

    valid_key_types = __validate_lines_keys_types_before_build!(lines_d, e)
    if !valid_key_types
        return false
    end

    d["lines"] = Lines(lines_d, buses, e)
    return d["lines"] !== nothing
end

function __cast_lines_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __cast_system_entities_content!(d, "lines", e)
end