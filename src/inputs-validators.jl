# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_inputs_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    input_keys = ["path", "files"]
    input_key_types = [String, Dict{String,Any}]

    valid_keys = __validate_keys!(d, input_keys, e)
    valid_key_types = valid_keys && __validate_key_types!(d, input_keys, input_key_types, e)

    return valid_key_types
end

function __validate_input_files_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    input_file_keys = ["algorithm", "resources", "scenarios", "system", "constraints"]
    input_file_key_types = [String, String, String, String, String]

    valid_file_keys = __validate_keys!(d, input_file_keys, e)
    valid_file_key_types =
        valid_file_keys &&
        __validate_key_types!(d, input_file_keys, input_file_key_types, e)

    return valid_file_key_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_entrypoint!(
    d::Union{Dict{String,Any},Nothing}, e::CompositeException
)::Bool
    read_success = d !== nothing

    keys = ["task", "inputs", "outputs"]
    types = [String, Dict{String,Any}, Dict{String,Any}]

    valid_keys = read_success && __validate_keys!(d, keys, e)
    valid_key_types = valid_keys && __validate_key_types!(d, keys, types, e)
    return valid_key_types
end

function __validate_inputs!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_inputs_keys_types!(d, e)
    valid_file_key_types =
        valid_key_types && __validate_input_files_keys_types!(d["files"], e)
    valid_directory = valid_file_key_types && __validate_directory!(d["path"], e)
    valid_directory && cd(d["path"])

    return valid_directory
end
