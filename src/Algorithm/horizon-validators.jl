# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_horizon_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["horizon"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["horizon"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_explicit_horizon_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["stages"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["stages"], [Vector{Stage}], e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_explicit_horizon_stages!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    stages = d["stages"]
    num_stages = length(stages)
    not_empty = num_stages > 0
    not_empty ||
        push!(e, AssertionError("Horizon - must have at least one stage ($num_stages)"))
    return not_empty
end

function __validate_explicit_horizon_content!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stages = __validate_explicit_horizon_stages!(d, e)
    return valid_stages
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_sequential_horizon_stage_indexes!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    stages = d["stages"]
    num_stages = length(stages)
    valid = true
    for i in 1:(num_stages - 1)
        stage = stages[i]
        next_stage = stages[i + 1]
        stage_index = stage.index
        next_index = next_stage.index
        valid_index = next_index == stage_index + 1
        valid_index || push!(
            e,
            AssertionError(
                "Horizon - stage index ($next_index) must be equal to $stage_index + 1"
            ),
        )

        valid = valid && valid_index
    end

    return valid
end

function __validate_sequential_horizon_stage_dates!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    stages = d["stages"]
    num_stages = length(stages)
    valid = true
    for i in 1:(num_stages - 1)
        stage = stages[i]
        next_stage = stages[i + 1]
        stage_end = stage.end_date
        next_stage_start = next_stage.start_date
        valid_date = stage_end <= next_stage_start
        valid_date || push!(
            e,
            AssertionError(
                "Horizon - stage start date ($next_stage_start) must be after $stage_end",
            ),
        )
        valid = valid && valid_date
    end

    return valid
end

function __validate_explicit_horizon_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_indexes = __validate_sequential_horizon_stage_indexes!(d, e)
    valid_dates = __validate_sequential_horizon_stage_dates!(d, e)
    return valid_indexes && valid_dates
end

# HELPERS -------------------------------------------------------------------------------------

function __build_explicit_horizon_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_stages = __build_stages!(d, e)
    return valid_stages
end
