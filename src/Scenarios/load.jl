
# CLASS DeterministicLoad -----------------------------------------------------------------------

struct DeterministicLoadValue
    bus_id::Integer
    stage_index::Integer
    value::Real
end

function DeterministicLoadValue(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_deterministic_load_value_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_deterministic_load_value_content!(d, e)
    valid = valid_content

    return if valid
        DeterministicLoadValue(d["bus_id"], d["stage_index"], d["value"])
    else
        nothing
    end
end

struct DeterministicLoad <: LoadScenarios
    values::Vector{DeterministicLoadValue}
end

function DeterministicLoad(d::Dict{String,Any}, e::CompositeException)
    valid_values = __build_deterministic_load_values!(d, e)
    valid_internals = valid_values

    valid_keys_types = valid_internals && __validate_deterministic_load_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_deterministic_load_content!(d, e)
    valid_consistency = valid_content && __validate_deterministic_load_consistency!(d, e)

    return valid_consistency ? DeterministicLoad(d["values"]) : nothing
end

function __get_load(bus_id::Integer, stage_index::Integer, load::DeterministicLoad)::Real
    for value in load.values
        if value.bus_id == bus_id && value.stage_index == stage_index
            return value.value
        end
    end
    return 0.0
end

# GENERAL METHODS --------------------------------------------------------------------------

function __get_ids(s::DeterministicLoad)
    return collect(Set(map(x -> x.bus_id, values(s.values))))
end

function length(s::DeterministicLoad)
    return length(__get_ids(s))
end

# HELPERS -------------------------------------------------------------------------------------

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