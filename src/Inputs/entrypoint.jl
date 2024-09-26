# CLASS Entrypoint -----------------------------------------------------------------------

function Entrypoint(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_entrypoint_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_entrypoint_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_entrypoint_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_entrypoint_consistency!(d, e)

    return if valid_consistency
        Entrypoint(d["inputs"])
    else
        nothing
    end
end

function Entrypoint(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_entrypoint_internals_from_files!(d, e)

    return valid ? Entrypoint(d, e) : nothing
end