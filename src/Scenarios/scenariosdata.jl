function ScenariosData(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_scenarios_internals_from_dicts!(d, e)
    valid_schema = valid_internals && validate_schema!(d, SCENARIOS_DATA_SCHEMA, e)
    valid_keys_types = valid_schema && __validate_scenarios_keys_types!(d, e)
    valid_consistency = valid_keys_types && __validate_scenarios_consistency!(d, e)

    return if valid_consistency
        ScenariosData(
            d["seed"],
            d["initial_season"],
            d["branchings"],
            d["graph"],
            d["inflow"],
            d["load"],
            d["block_config"],
            d["markov_chain"],
        )
    else
        nothing
    end
end

function ScenariosData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing
    valid = valid_jsonc && __cast_scenarios_internals_from_files!(d, e)

    return valid ? ScenariosData(d, e) : nothing
end

function get_scenarios(f::Vector{InputModule})::ScenariosData
    return get_input_module(f, ScenariosData)
end
