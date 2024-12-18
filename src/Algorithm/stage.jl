# CLASS Stage -----------------------------------------------------------------------

function Stage(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_stage_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_stage_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_stage_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_stage_consistency!(d, e)

    return valid_consistency ? Stage(d["index"], d["start_date"], d["end_date"]) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

# HELPERS --------------------------------------------------------------------------

function __build_stages!(d::Dict{String,Any}, e::CompositeException)::Bool
    stages = d["stages"]
    entities = Stage[]
    valid = true
    for i in eachindex(stages)
        entity = Stage(stages[i], e)
        if entity !== nothing
            push!(entities, entity)
        else
            valid = false
        end
    end
    d["stages"] = entities
    return valid
end

function __cast_stage_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
