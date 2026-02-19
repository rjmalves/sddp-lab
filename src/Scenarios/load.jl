
struct DeterministicLoadValue
    bus_id::Integer
    node_id::Integer
    value::Real
    block_name::String
end

function DeterministicLoadValue(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, DETERMINISTIC_LOAD_VALUE_SCHEMA, e)
    if !valid
        return nothing
    end
    block_name = get(d, "block", "")
    return DeterministicLoadValue(d["bus_id"], d["node_id"], d["value"], String(block_name))
end

function DeterministicLoadValue(bus_id::Integer, node_id::Integer, value::Real)
    return DeterministicLoadValue(bus_id, node_id, value, "")
end

struct DeterministicLoad <: LoadScenarios
    values::Vector{DeterministicLoadValue}
end

function DeterministicLoad(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_deterministic_load_values!(d, e)
    valid_keys_types = valid_internals && __validate_deterministic_load_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_deterministic_load_content!(d, e)
    valid_consistency = valid_content && __validate_deterministic_load_consistency!(d, e)

    return valid_consistency ? DeterministicLoad(d["values"]) : nothing
end

function __get_load(bus_id::Integer, node_id::Integer, load::DeterministicLoad)::Real
    for value in load.values
        if value.bus_id == bus_id && value.node_id == node_id
            return value.value
        end
    end
    @warn "No load value found for bus_id=$bus_id at node_id=$node_id, defaulting to 0.0"
    return 0.0
end

function __get_load(
    bus_id::Integer, node_id::Integer, block_idx::Integer, load::DeterministicLoad
)::Real
    return __get_load(bus_id, node_id, load)
end

function __get_load_by_block_name(
    bus_id::Integer, node_id::Integer, block_name::String, load::DeterministicLoad
)::Real
    for value in load.values
        if value.bus_id == bus_id && value.node_id == node_id && value.block_name == block_name
            return value.value
        end
    end
    if block_name != ""
        @warn "No load value found for bus_id=$bus_id, node_id=$node_id, block='$block_name', defaulting to 0.0"
    end
    return 0.0
end

function __get_ids(s::DeterministicLoad)
    return collect(Set(map(x -> x.bus_id, values(s.values))))
end

function length(s::DeterministicLoad)
    return length(__get_ids(s))
end

function __build_deterministic_load_values!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_values_key = __validate_keys!(d, ["values"], e)
    valid_values_type =
        valid_values_key &&
        __validate_key_types!(d, ["values"], [Vector{Dict{String,Any}}], e)
    if !valid_values_type
        return false
    end

    values = d["values"]
    entities = DeterministicLoadValue[]
    valid = true
    for i in eachindex(values)
        entity = DeterministicLoadValue(values[i], e)
        if entity !== nothing
            push!(entities, entity)
        else
            valid = false
        end
    end
    d["values"] = entities
    return valid
end

function __build_load_scenarios!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_load_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "load", e)
end

function __cast_load_scenarios_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    load_d = d["load"]
    should_cast_from_file = __validate_file_key!(load_d, e)

    valid = !should_cast_from_file
    if should_cast_from_file
        valid = __validate_cast_from_csv_file!(load_d, "values", e)
    end

    return valid
end
