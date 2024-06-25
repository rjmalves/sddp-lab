# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_stage_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["index", "start_date", "end_date"], e)
    valid_types = __validate_key_types!(
        d, ["index", "start_date", "end_date"], [Integer, DateTime, DateTime], e
    )
    return valid_keys && valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_stage_index!(d::Dict{String,Any}, e::CompositeException)::Bool
    index = d["index"]
    valid = index > 0
    valid || push!(e, AssertionError("Stage index ($index) must be positive"))
    return valid
end

function __validate_stage_dates!(d::Dict{String,Any}, e::CompositeException)::Bool
    index = d["index"]
    start_date = d["start_date"]
    end_date = d["end_date"]
    valid = start_date < end_date
    valid || push!(
        e,
        AssertionError("Stage $index - start_date ($name) must be < end_date ($end_date)"),
    )
    return valid
end

function __validate_stage_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_index = __validate_stage_index!(d, e)
    valid_dates = __validate_stage_dates!(d, e)
    return valid_index && valid_dates
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------
