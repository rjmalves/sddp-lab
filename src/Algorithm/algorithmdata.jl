# CLASS AlgorithmData -----------------------------------------------------------------------

struct AlgorithmData <: InputModule
    graph::ScenarioGraph
    horizon::Horizon
    risk::RiskMeasure
end

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
