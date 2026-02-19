const DETERMINISTIC_LOAD_VALUE_SCHEMA = [
    FieldRule("bus_id", Integer; constraints = [positive()]),
    FieldRule("node_id", Integer; constraints = [positive()]),
    FieldRule("value", Real),
]

function __validate_load_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["load"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_deterministic_load_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["values"]
    keys_types = [Vector{DeterministicLoadValue}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_deterministic_load_values!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    values = d["values"]
    num_values = length(values)
    not_empty = num_values > 0
    not_empty ||
        push!(e, AssertionError("Load - must have at least one value ($num_values)"))
    return not_empty
end

function __validate_deterministic_load_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return __validate_deterministic_load_values!(d, e)
end

function __validate_deterministic_load_unique_bus_node_pairs!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    values = d["values"]
    seen = Set{Tuple{Integer,Integer,String}}()
    valid = true
    for v in values
        triple = (v.bus_id, v.node_id, v.block_name)
        if triple in seen
            block_msg = v.block_name == "" ? "" : ", block='$(v.block_name)'"
            push!(
                e,
                AssertionError(
                    "Load - duplicate entry for (bus_id=$(v.bus_id), node_id=$(v.node_id)$block_msg)"
                ),
            )
            valid = false
        else
            push!(seen, triple)
        end
    end
    return valid
end

function __validate_deterministic_load_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return __validate_deterministic_load_unique_bus_node_pairs!(d, e)
end
