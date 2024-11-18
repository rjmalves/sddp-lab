# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

WORK_KEYS = ["tasks"]
WORK_KEY_TYPES = [Vector{TaskDefinition}]
WORK_KEY_TYPES_BEFORE_BUILD = [Vector{Dict{String,Any}}]

function __validate_tasksdata_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = WORK_KEYS
    keys_types = WORK_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_tasksdata_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = WORK_KEYS
    keys_types = WORK_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_tasksdata_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

# TODO - implement this and other aux functions
function __validate_simulation_task_null_policy_path(
    tasks::Vector{TaskDefinition}, e::CompositeException
) end

function __validate_tasksdata_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    task_vector = d["tasks"]
    policy_index = findfirst(x -> isa(x, Policy), task_vector)
    simulation_index = findfirst(x -> isa(x, Simulation), task_vector)
    # TODO - validate relationship between policy and simulation
    # If not policy.load:
    # - Must have a policy task defined before
    # Else:
    # - Directory exists or is the output path of policy (with save = true)
    # - Launch warning in this case
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_tasksdata_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_tasks = __build_tasks!(d, e)
    return valid_tasks
end

function __cast_tasksdata_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end