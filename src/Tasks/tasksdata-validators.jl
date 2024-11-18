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
function __validate_simulation_task_policy_load_path(tasks::Vector{TaskDefinition},e::CompositeException)::Bool
    # Validate if policy path exists or is the output path of previous policy task
    simulation = tasks[findfirst(x -> isa(x, Simulation), tasks)]
    valid_load_path = __validate_directory!(simulation.policy.path, e)
    
    policy_index = findfirst(x -> isa(x, Policy), tasks)
    if policy_index == nothing
        return valid_load_path
    end
    simulation_policy_path = simulation.policy.path
    policy = tasks[policy_index]
    policy_path = policy.results.path
    policy_save = policy.results.save

    valid_simulation_policy_path = (policy_save == true) & (simulation_policy_path == policy_path)
    valid = valid_load_path | valid_simulation_policy_path
    valid || push!(e, ErrorException("The loaded policy path $simulation_policy_path is not valid."))
    return valid
end

function __validate_simulation_task_with_policy_task(tasks::Vector{TaskDefinition},e::CompositeException)::Bool
    # Validate relationship between policy and simulation
    # If policy path not defined, must have a policy task defined before
    simulation_index = findfirst(x -> isa(x, Simulation), tasks)
    policy_index = findfirst(x -> isa(x, Policy), tasks)
    valid_simulation_policy = (policy_index !== nothing) && (simulation_index > policy_index)
    valid_simulation_policy || push!(e, ErrorException("Either needs to define a policy task prior to simulation task or load a policy."))
    return valid_simulation_policy
end

function __validate_simulation_task_policy(
    tasks::Vector{TaskDefinition},  e::CompositeException
)::Bool
    simulation_index = findfirst(x -> isa(x, Simulation), tasks)
    simulation = tasks[simulation_index]

    policy_index = findfirst(x -> isa(x, Policy), tasks)
    if policy_index !== nothing
        policy = tasks[policy_index]
    end

    valid = simulation.policy.load ? __validate_simulation_task_policy_load_path(tasks,e) : __validate_simulation_task_with_policy_task(tasks,e)
    return valid
end

function __validate_tasksdata_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    task_vector = d["tasks"]
    simulation_index = findfirst(x -> isa(x, Simulation), task_vector)
    valid_simulation_policy = simulation_index != nothing ? __validate_simulation_task_policy(task_vector,e) : true
    valid_consistency = valid_simulation_policy
    return valid_consistency
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