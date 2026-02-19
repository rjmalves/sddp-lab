# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

CONFIGURATION_KEYS = ["buses", "lines", "hydros", "thermals"]
CONFIGURATION_KEY_TYPES = [Buses, Lines, Hydros, Thermals]
CONFIGURATION_KEY_TYPES_BEFORE_BUILD = [
    Dict{String,Any}, Dict{String,Any}, Dict{String,Any}, Dict{String,Any}
]

function __validate_system_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = CONFIGURATION_KEYS
    keys_types = CONFIGURATION_KEY_TYPES
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

function __validate_system_keys_types_before_build!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    keys = CONFIGURATION_KEYS
    keys_types = CONFIGURATION_KEY_TYPES_BEFORE_BUILD
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_system_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_system_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# HELPER FUNCTIONS ------------------------------------------------------------------------

function __build_system_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_buses = __build_buses!(d, e)
    valid_lines = valid_buses && __build_lines!(d, d["buses"], e)
    valid_hydros = valid_buses && __build_hydros!(d, d["buses"], e)
    valid_thermals = valid_buses && __build_thermals!(d, d["buses"], e)
    valid_noncontrollables = if haskey(d, "noncontrollables")
        valid_buses && __build_noncontrollables!(d, d["buses"], e)
    else
        d["noncontrollables"] = NonControllables(NonControllable[])
        true
    end
    valid_energycontracts = if haskey(d, "energycontracts")
        valid_buses && __build_energycontracts!(d, d["buses"], e)
    else
        d["energycontracts"] = EnergyContracts(EnergyContract[])
        true
    end
    valid_pumpingstations = if haskey(d, "pumpingstations")
        (valid_buses && valid_hydros) && __build_pumpingstations!(d, d["buses"], d["hydros"], e)
    else
        d["pumpingstations"] = PumpingStations(PumpingStation[])
        true
    end
    return valid_lines && valid_hydros && valid_thermals && valid_noncontrollables && valid_energycontracts && valid_pumpingstations
end

function __cast_system_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_system_keys_types_before_build!(d, e)
    valid_buses = valid_key_types && __cast_buses_internals_from_files!(d, e)
    valid_lines = valid_key_types && __cast_lines_internals_from_files!(d, e)
    valid_hydros = valid_key_types && __cast_hydros_internals_from_files!(d, e)
    valid_thermals = valid_key_types && __cast_thermals_internals_from_files!(d, e)
    valid_noncontrollables = if haskey(d, "noncontrollables")
        valid_key_types && __cast_noncontrollables_internals_from_files!(d, e)
    else
        true
    end
    valid_energycontracts = if haskey(d, "energycontracts")
        valid_key_types && __cast_energycontracts_internals_from_files!(d, e)
    else
        true
    end
    valid_pumpingstations = if haskey(d, "pumpingstations")
        valid_key_types && __cast_pumpingstations_internals_from_files!(d, e)
    else
        true
    end

    return valid_buses && valid_lines && valid_hydros && valid_thermals && valid_noncontrollables && valid_energycontracts && valid_pumpingstations
end