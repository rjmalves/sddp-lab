# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

FILES_KEYS = ["algorithm", "resources", "scenarios", "system", "tasks"]
FILES_KEY_TYPES = [AlgorithmData, ResourcesData, ScenariosData, SystemData, TasksData]
FILES_KEY_TYPES_BEFORE_BUILD = [String, String, String, String, String]

function __validate_files_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["files"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["files"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_files_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = FILES_KEYS
    keys_types = FILES_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_files_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = FILES_KEYS
    keys_types = FILES_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_files_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_files_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPERS ----------------------------------------------------------------------------------

function __build_files_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    d["algorithm"] = AlgorithmData(d["algorithm"], e)
    valid_algorithm = d["algorithm"] !== nothing
    d["resources"] = ResourcesData(d["resources"], e)
    valid_resources = d["resources"] !== nothing
    d["scenarios"] = ScenariosData(d["scenarios"], e)
    valid_scenarios = d["scenarios"] !== nothing
    d["system"] = SystemData(d["system"], e)
    valid_system = d["system"] !== nothing
    d["tasks"] = TasksData(d["tasks"], e)
    valid_tasks = d["tasks"] !== nothing
    return valid_algorithm &&
           valid_resources &&
           valid_scenarios &&
           valid_system &&
           valid_tasks
end
