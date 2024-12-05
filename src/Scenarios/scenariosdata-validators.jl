# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

UNCERTAINTIES_KEYS = ["seed", "initial_season", "branchings", "inflow", "load"]
UNCERTAINTIES_KEY_TYPES = [
    Integer, Integer, Integer, T where {T<:InflowScenarios}, T where {T<:LoadScenarios}
]
UNCERTAINTIES_KEY_TYPES_BEFORE_BUILD = [
    Integer, Integer, Integer, Dict{String,Any}, Dict{String,Any}
]

function __validate_scenarios_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = UNCERTAINTIES_KEYS
    keys_types = UNCERTAINTIES_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_scenarios_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = UNCERTAINTIES_KEYS
    keys_types = UNCERTAINTIES_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_scenarios_initial_season!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    season = d["initial_season"]
    valid = season > 0
    valid ||
        push!(e, AssertionError("Uncertainties initial_season ($season) must be positive"))
    return valid
end

function __validate_scenarios_branchings!(d::Dict{String,Any}, e::CompositeException)::Bool
    branchings = d["branchings"]
    valid = branchings > 0
    valid ||
        push!(e, AssertionError("Uncertainties branchings ($branchings) must be positive"))
    return valid
end

function __validate_scenarios_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_initial_season = __validate_scenarios_initial_season!(d, e)
    valid_branchings = valid_initial_season && __validate_scenarios_branchings!(d, e)
    return valid_branchings
end

# CONSISTENCY VALIDATORS -----------------------------------------------------------------------

function __validate_scenarios_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_scenarios_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_inflow = __build_inflow_scenarios!(d, e)
    valid_load = __build_load_scenarios!(d, e)
    return valid_inflow && valid_load
end

function __cast_scenarios_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_scenarios_keys_types_before_build!(d, e)
    valid_inflow = valid_key_types && __cast_inflow_scenarios_internals_from_files!(d, e)
    valid_load = valid_key_types && __cast_load_scenarios_internals_from_files!(d, e)
    return valid_inflow && valid_load
end