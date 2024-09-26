# CLASS ScenariosData -----------------------------------------------------------------------

function ScenariosData(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_scenarios_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_scenarios_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_scenarios_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_scenarios_consistency!(d, e)

    return if valid_consistency
        ScenariosData(d["initial_season"], d["branchings"], d["inflow"], d["load"])
    else
        nothing
    end
end

function ScenariosData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_scenarios_internals_from_files!(d, e)

    return valid ? ScenariosData(d, e) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

"""
get_scenarios(s::Vector{InputModule})::ScenariosData

Return the ScenariosData object from files.
"""
function get_scenarios(f::Vector{InputModule})::ScenariosData
    return get_input_module(f, ScenariosData)
end
