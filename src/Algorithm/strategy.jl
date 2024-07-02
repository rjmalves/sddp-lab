# CLASS Strategy -----------------------------------------------------------------------

struct Strategy
    graph::ScenarioGraph
    horizon::Horizon
    risk::RiskMeasure
    convergence::Convergence
end

function Strategy(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_strategy_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_strategy_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_strategy_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_strategy_consistency!(d, e)

    return if valid_consistency
        Strategy(d["scenario_graph"], d["horizon"], d["risk_measure"], d["convergence"])
    else
        nothing
    end
end

function Strategy(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_strategy_internals_from_files!(d, e)

    return valid ? Strategy(d, e) : nothing
end
