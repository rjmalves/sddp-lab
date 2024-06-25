# CLASS Stage -----------------------------------------------------------------------

function Stage(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_stage_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_stage_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? Stage(d["index"], d["start_date"], d["end_date"]) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

# GENERAL METHODS --------------------------------------------------------------------------

function __build_stages!(d::Dict{String,Any}, e::CompositeException)::Bool
    stages = d["stages"]
    entities = Stage[]
    valid = true
    for i in 1:length(stages)
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