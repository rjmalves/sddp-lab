# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

CONFIGURATION_KEYS = ["buses", "lines", "hydros", "thermals"]
CONFIGURATION_KEY_TYPES = [Buses, Lines, Hydros, Thermals]
CONFIGURATION_KEY_TYPES_BEFORE_BUILD = [
    Dict{String,Any}, Dict{String,Any}, Dict{String,Any}, Dict{String,Any}
]

function __validate_configuration_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONFIGURATION_KEYS
    keys_types = CONFIGURATION_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_configuration_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONFIGURATION_KEYS
    keys_types = CONFIGURATION_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_system_entity_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_entity_keys = __validate_keys!(d, ["entities"], e)
    valid_entity_types =
        valid_entity_keys &&
        __validate_key_types!(d, ["entities"], [Vector{Dict{String,Any}}], e)

    return valid_entity_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_configuration_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_configuration_consistency!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_configuration_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_buses = __build_buses!(d, e)
    valid_lines = valid_buses && __build_lines!(d, d["buses"], e)
    valid_hydros = valid_buses && __build_hydros!(d, d["buses"], e)
    valid_thermals = valid_buses && __build_thermals!(d, d["buses"], e)
    return valid_lines && valid_hydros && valid_thermals
end

function __cast_configuration_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_configuration_keys_types_before_build!(d, e)
    valid_buses = valid_key_types && __cast_buses_internals_from_files!(d, e)
    valid_lines = valid_key_types && __cast_lines_internals_from_files!(d, e)
    valid_hydros = valid_key_types && __cast_hydros_internals_from_files!(d, e)
    valid_thermals = valid_key_types && __cast_thermals_internals_from_files!(d, e)

    return valid_buses && valid_lines && valid_hydros && valid_thermals
end