# CLASS Echo -----------------------------------------------------------------------

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

function run_task(
    t::Echo, a::Vector{TaskArtifact}, e::CompositeException
)::Union{EchoArtifact,Nothing}
    input_index = findfirst(x -> isa(x, InputsArtifact), a)
    if (t.results.save)
        for (root, dirs, files) in walkdir(a[input_index].path)
            for file in files
                mkpath(t.results.path)
                cp(joinpath(root, file), joinpath(t.results.path, file); force = true)
            end
        end
    end
    files = a[input_index].files
    return EchoArtifact(t, files)
end

# CLASS Policy  -----------------------------------------------------------------------

function Policy(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_policy_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_policy_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_policy_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_policy_consistency!(d, e)

    return if valid_consistency
        Policy(d["convergence"], d["risk_measure"], d["parallel_scheme"], d["results"])
    else
        nothing
    end
end

function run_task(
    t::Policy, a::Vector{TaskArtifact}, e::CompositeException
)::Union{PolicyArtifact,Nothing}
    input_index = findfirst(x -> isa(x, InputsArtifact), a)
    files = a[input_index].files
    model = __build_model(files)
    __train_model(model, get_convergence(t), get_risk_measure(t), get_parallel_scheme(t))
    return PolicyArtifact(t, model, files)
end

# CLASS Simulation  -----------------------------------------------------------------------

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
        Simulation(
            d["num_simulated_series"], d["policy"], d["parallel_scheme"], d["results"]
        )
    else
        nothing
    end
end

function run_task(
    t::Simulation, a::Vector{TaskArtifact}, e::CompositeException
)::Union{SimulationArtifact,Nothing}
    files_index = findfirst(x -> isa(x, InputsArtifact), a)
    files = a[files_index].files
    # TODO - implement support for external (previously evaluated) policies
    # If t.policy.load: ignore PolicyArtifact -> make a new SDDP.PolicyGraph with
    #    external cuts.
    # Else: require and check for a PolicyArtifact in the TaskArtifact vector
    if t.policy.load
        reader = get_reader(t.policy.format)
        extension = get_extension(t.policy.format)
        PROCESSED_CUTS_PATH = POLICY_CUTS_OUTPUT_FILENAME * extension
        @info "Reading cuts from $(PROCESSED_CUTS_PATH)"
        df = reader(PROCESSED_CUTS_PATH, e)
        # TODO - validate succesfully read df (!== nothing)
        # TODO - implement in model.jl
        policy = __build_model(files)
        __load_external_cuts!(policy, df)
    else
        # TODO - check for sanity (policy_index !== nothing)
        policy_index = findfirst(x -> isa(x, PolicyArtifact), a)
        policy = a[policy_index].policy
    end
    sims = __simulate_model(policy, files, t.num_simulated_series, t.parallel_scheme)
    return SimulationArtifact(t, sims, files)
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
    valid_risk_measure = __cast_risk_measure_internals_from_files!(d, e)
    return valid_risk_measure
end

function __cast_simulation_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
