
# CLASS SystemData -----------------------------------------------------------------------

function SystemData(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_system_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_system_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_system_content!(d, e)
    valid_consistency = valid_content && __validate_system_consistency!(d, e)

    return if valid_consistency
        SystemData(
            d["buses"], d["lines"], d["hydros"], d["thermals"],
            d["noncontrollables"], d["energycontracts"], d["pumpingstations"],
        )
    else
        nothing
    end
end

function SystemData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid = d !== nothing && __cast_system_internals_from_files!(d, e)
    return valid ? SystemData(d, e) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

"""
get_system(s::Vector{InputModule})::SystemData

Return the SystemData object from files.
"""
function get_system(f::Vector{InputModule})::SystemData
    return get_input_module(f, SystemData)
end

"""
get_hydros(s::SystemData)::Hydros

Return the hydro object from files.
"""
function get_hydros(s::SystemData)::Hydros
    return s.hydros
end

"""
get_hydros_entities(s::SystemData)::Vector{Hydro}

Return the hydro entities from files.
"""
function get_hydros_entities(s::SystemData)::Vector{Hydro}
    return s.hydros.entities
end

"""
get_buses(s::SystemData)::Buses

Return the buses object from files.
"""
function get_buses(s::SystemData)::Buses
    return s.buses
end

"""
get_buses_entities(s::SystemData)::Vector{Bus}

Return the bus entities from files.
"""
function get_buses_entities(s::SystemData)::Vector{Bus}
    return s.buses.entities
end

"""
get_thermals(s::SystemData)::Thermals

Return the thermals object from files.
"""
function get_thermals(s::SystemData)::Thermals
    return s.thermals
end

"""
get_thermals_entities(s::SystemData)::Vector{Thermal}

Return the thermal entities from files.
"""
function get_thermals_entities(s::SystemData)::Vector{Thermal}
    return s.thermals.entities
end

"""
get_lines(s::SystemData)::Lines

Return the lines object from files.
"""
function get_lines(s::SystemData)::Lines
    return s.lines
end

"""
get_lines_entities(s::SystemData)::Vector{Line}

Return the line entities from files.
"""
function get_lines_entities(s::SystemData)::Vector{Line}
    return s.lines.entities
end

"""
get_noncontrollables(s::SystemData)::NonControllables

Return the noncontrollables object from files.
"""
function get_noncontrollables(s::SystemData)::NonControllables
    return s.noncontrollables
end

"""
get_noncontrollables_entities(s::SystemData)::Vector{NonControllable}

Return the noncontrollable entities from files.
"""
function get_noncontrollables_entities(s::SystemData)::Vector{NonControllable}
    return s.noncontrollables.entities
end

"""
get_energycontracts(s::SystemData)::EnergyContracts

Return the energy contracts object from files.
"""
function get_energycontracts(s::SystemData)::EnergyContracts
    return s.energycontracts
end

"""
get_energycontracts_entities(s::SystemData)::Vector{EnergyContract}

Return the energy contract entities from files.
"""
function get_energycontracts_entities(s::SystemData)::Vector{EnergyContract}
    return s.energycontracts.entities
end

"""
get_pumpingstations(s::SystemData)::PumpingStations

Return the pumping stations object from files.
"""
function get_pumpingstations(s::SystemData)::PumpingStations
    return s.pumpingstations
end

"""
get_pumpingstations_entities(s::SystemData)::Vector{PumpingStation}

Return the pumping station entities from files.
"""
function get_pumpingstations_entities(s::SystemData)::Vector{PumpingStation}
    return s.pumpingstations.entities
end
