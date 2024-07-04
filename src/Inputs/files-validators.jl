# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

FILES_KEYS = ["algorithm", "resources", "scenarios", "system", "tasks"]
FILES_KEY_TYPES = [Strategy, Environment, Uncertainties, Configuration, Work]
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
    d["algorithm"] = Strategy(d["algorithm"], e)
    valid_algorithm = d["algorithm"] !== nothing
    d["resources"] = Environment(d["resources"], e)
    valid_resources = d["resources"] !== nothing
    d["scenarios"] = Uncertainties(d["scenarios"], e)
    valid_scenarios = d["scenarios"] !== nothing
    d["system"] = Configuration(d["system"], e)
    valid_system = d["system"] !== nothing
    d["tasks"] = Work(d["tasks"], e)
    valid_tasks = d["tasks"] !== nothing
    return valid_algorithm &&
           valid_resources &&
           valid_scenarios &&
           valid_system &&
           valid_tasks
end
