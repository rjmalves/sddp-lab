# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_load_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["load"]
    keys_types = [Dict{String,Any}]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_deterministic_load_value_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["bus_id", "stage_index", "value"]
    keys_types = [Integer, Integer, Real]
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

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_deterministic_load_value_bus_id!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    id = d["bus_id"]
    valid = id > 0
    valid || push!(e, AssertionError("Load bus_id ($id) must be positive"))
    return valid
end

function __validate_deterministic_load_value_stage_index!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    index = d["stage_index"]
    valid = index > 0
    valid || push!(e, AssertionError("Load stage_index ($index) must be positive"))
    return valid
end

function __validate_deterministic_load_value_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_index = __validate_deterministic_load_value_bus_id!(d, e)
    valid_dates = __validate_deterministic_load_value_stage_index!(d, e)
    return valid_index && valid_dates
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
    valid_values = __validate_deterministic_load_values!(d, e)
    return valid_values
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_sequential_deterministic_load_stage_indexes!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    values = d["values"]
    num_values = length(values)
    valid = true
    for i in 1:(num_values - 1)
        load_value = values[i]
        next_load_value = values[i + 1]
        stage_index = load_value.stage_index
        next_index = next_load_value.stage_index
        valid_index = (next_index == stage_index + 1) || (next_index == 1)
        valid_index || push!(
            e,
            AssertionError(
                "Load - stage index ($next_index) must be equal to $stage_index + 1"
            ),
        )

        valid = valid && valid_index
    end

    return valid
end

function __validate_deterministic_load_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_indexes = __validate_sequential_deterministic_load_stage_indexes!(d, e)
    return valid_indexes
end
