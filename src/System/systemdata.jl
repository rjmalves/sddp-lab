
# CLASS SystemData -----------------------------------------------------------------------

function SystemData(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_system_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_system_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_system_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_system_consistency!(d, e)

    return if valid_consistency
        SystemData(d["buses"], d["lines"], d["hydros"], d["thermals"])
    else
        nothing
    end
end

function SystemData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_system_internals_from_files!(d, e)

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
