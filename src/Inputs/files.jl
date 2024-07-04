# CLASS Files -----------------------------------------------------------------------

function Files(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_files_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_files_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_files_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_files_consistency!(d, e)

    return if valid_consistency
        Files(d["algorithm"], d["resources"], d["system"], d["scenarios"], d["tasks"])
    else
        nothing
    end
end

function __build_files!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_files_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    files_d = d["files"]

    valid_key_types = __validate_files_keys_types_before_build!(files_d, e)
    if !valid_key_types
        return false
    end

    d["files"] = Files(files_d, e)
    return d["files"] !== nothing
end

function __cast_files_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
