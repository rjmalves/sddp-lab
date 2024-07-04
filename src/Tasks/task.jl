
# CLASS Echo -----------------------------------------------------------------------

struct Echo <: TaskDefinition
    results::Results
end

function Echo(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_echo_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_echo_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_echo_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_echo_consistency!(d, e)

    return valid_consistency ? Echo(d["results"]) : nothing
end

# CLASS Policy -----------------------------------------------------------------------

struct Policy <: TaskDefinition
    convergence::Convergence
    results::Results
end

function Policy(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_policy_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_policy_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_policy_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_policy_consistency!(d, e)

    return valid_consistency ? Policy(d["convergence"], d["results"]) : nothing
end

# CLASS Simulation -----------------------------------------------------------------------

struct Simulation <: TaskDefinition
    num_simulated_series::Integer
    policy_path::String
    results::Results
end

function Simulation(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_simulation_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_simulation_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_simulation_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_simulation_consistency!(d, e)

    return if valid_consistency
        Simulation(d["num_simulated_series"], d["policy_path"], d["results"])
    else
        nothing
    end
end

# HELPERS -------------------------------------------------------------------------------------

function __build_tasks!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_tasks_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "tasks", e)
end

function __cast_policy_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __cast_simulation_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
