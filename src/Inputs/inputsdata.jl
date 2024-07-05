# CLASS InputsData -----------------------------------------------------------------------

function InputsData(d::Dict{String,Any}, e::CompositeException)

    # TODO - the error is in these functions below

    # Build internal objects
    valid_internals = __build_inputsdata_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_inputsdata_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_inputsdata_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_inputsdata_consistency!(d, e)

    return if valid_consistency
        InputsData(d["path"], d["files"])
    else
        nothing
    end
end

function __build_inputsdata!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_inputsdata_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    inputs_d = d["inputs"]

    valid_key_types = __validate_inputsdata_keys_types_before_build!(inputs_d, e)
    if !valid_key_types
        return false
    end

    d["inputs"] = InputsData(inputs_d, e)
    return d["inputs"] !== nothing
end
