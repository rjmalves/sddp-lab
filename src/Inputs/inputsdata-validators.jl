# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

READING_KEYS = ["path", "files"]
READING_KEY_TYPES = [String, T where {T<:Vector{InputModule}}]
READING_KEY_TYPES_BEFORE_BUILD = [String, Dict{String,Any}]

function __validate_inputsdata_main_key_type!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["inputs"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["inputs"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_files_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["files"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["files"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_inputsdata_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = READING_KEYS
    keys_types = READING_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_inputsdata_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = READING_KEYS
    keys_types = READING_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_files_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = ["algorithm", "resources", "scenarios", "system", "tasks"]
    keys_types = [String, String, String, String, String]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_inputsdata_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_inputsdata_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_files!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_files_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    files_d = d["files"]

    @info files_d

    valid_key_types = __validate_files_keys_types_before_build!(files_d, e)
    if !valid_key_types
        return false
    end

    files_d["algorithm"] = AlgorithmData(files_d["algorithm"], e)
    valid_algorithm = files_d["algorithm"] !== nothing
    files_d["resources"] = ResourcesData(files_d["resources"], e)
    valid_resources = files_d["resources"] !== nothing
    files_d["scenarios"] = ScenariosData(files_d["scenarios"], e)
    valid_scenarios = files_d["scenarios"] !== nothing
    files_d["system"] = SystemData(files_d["system"], e)
    valid_system = files_d["system"] !== nothing
    files_d["tasks"] = TasksData(files_d["tasks"], e)
    valid_tasks = files_d["tasks"] !== nothing

    valid_files =
        valid_algorithm && valid_resources && valid_scenarios && valid_system && valid_tasks

    if valid_files
        d["files"] = [
            files_d["algorithm"],
            files_d["resources"],
            files_d["scenarios"],
            files_d["system"],
            files_d["tasks"],
        ]
    end

    return valid_files
end

function __build_inputsdata_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    curdir = pwd()
    valid_directory = __validate_directory!(d["path"], e)
    valid_directory && cd(d["path"])
    valid_files = valid_directory && __build_files!(d, e)
    cd(curdir)
    return valid_files
end

function __cast_inputsdata_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end