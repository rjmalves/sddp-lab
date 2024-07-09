# CLASS AlgorithmData -----------------------------------------------------------------------

function AlgorithmData(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_algorithm_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_algorithm_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_algorithm_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_algorithm_consistency!(d, e)

    return if valid_consistency
        AlgorithmData(d["scenario_graph"], d["horizon"], d["risk_measure"])
    else
        nothing
    end
end

function AlgorithmData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_algorithm_internals_from_files!(d, e)

    return valid ? AlgorithmData(d, e) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

"""
get_algorithm(s::Vector{InputModule})::AlgorithmData

Return the AlgorithmData object from files.
"""
function get_algorithm(f::Vector{InputModule})::AlgorithmData
    return get_input_module(f, AlgorithmData)
end

"""
get_horizon(s::AlgorithmData)::Horizon

Return the Horizon object from files.
"""
function get_horizon(s::AlgorithmData)::Horizon
    return s.horizon
end

"""
get_scenario_graph(s::AlgorithmData)::ScenarioGraph

Return the ScenarioGraph object from files.
"""
function get_scenario_graph(s::AlgorithmData)::ScenarioGraph
    return s.graph
end

"""
get_number_of_stages(s::AlgorithmData)::Integer

Return the hydro entities from files.
"""
function get_number_of_stages(s::AlgorithmData)::Integer
    h = get_horizon(s)
    return length(h)
end

# SDDP METHODS -----------------------------------------------------------------------------

"""
generate_scenario_graph(s::AlgorithmData)::AbstractSamplingScheme

Generates the SDDP.jl graph for building the model.
"""
function generate_scenario_graph(s::AlgorithmData)::SDDP.Graph
    num_stages = get_number_of_stages(s)
    return generate_scenario_graph(get_scenario_graph(s), num_stages)
end

"""
generate_sampler(s::AlgorithmData)::AbstractSamplingScheme

Generates the SDDP.jl sampler for simulating the model.
"""
function generate_sampler(s::AlgorithmData)::SDDP.AbstractSamplingScheme
    num_stages = get_number_of_stages(s)
    return SDDP.InSampleMonteCarlo(;
        max_depth = num_stages, terminate_on_dummy_leaf = false
    )
end
