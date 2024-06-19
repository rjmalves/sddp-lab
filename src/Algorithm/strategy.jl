
# CLASS Strategy -----------------------------------------------------------------------

struct Strategy
    graph::PolicyGraph
    risk::RiskMeasure
    convergence::Convergence
end

function Strategy(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_policy_graph = __build_policy_graph!(d, e)
    valid_risk_measure = __build_risk_measure!(d, e)
    valid_convergence = __build_convergence!(d, e)

    valid_internals = valid_policy_graph && valid_risk_measure && valid_convergence

    # Keys and types validation
    valid_keys_types = valid_internals ? __validate_strategy_keys_types!(d, e) : false

    # Content validation

    valid = valid_keys_types && valid_internals
    return if valid
        Strategy(d["policy_graph"], d["risk_measure"], d["convergence"])
    else
        nothing
    end
end

function Strategy(filename::String, e::CompositeException)
    d = read_jsonc(filename)
    return Strategy(d, e)
end
