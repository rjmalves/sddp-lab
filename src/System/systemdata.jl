
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

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, s::SystemData)
    add_system_elements!(m, get_buses(s))
    add_system_elements!(m, get_lines(s))
    add_system_elements!(m, get_thermals(s))
    add_system_elements!(m, get_hydros(s))
    add_hydro_balance!(m, get_hydros(s))
    return true
end

function add_system_objective!(m::JuMP.Model, s::SystemData)
    hydros = get_hydros_entities(s)
    buses = get_buses_entities(s)
    lines = get_lines_entities(s)
    thermals = get_thermals_entities(s)
    num_buses = length(buses)
    num_lines = length(lines)
    num_hydros = length(hydros)
    num_thermals = length(thermals)

    SDDP.@stageobjective(
        m,
        sum(thermals[n].cost * m[THERMAL_GENERATION][n] for n in 1:num_thermals) +
            sum(buses[n].deficit_cost * m[DEFICIT][n] for n in 1:num_buses) +
            sum(lines[n].exchange_penalty * abs(m[EXCHANGE][n]) for n in 1:num_lines) +
            sum(
                hydros[n].bus[].deficit_cost * 1.0001 * m[HYDRO_MIN_GENERATION_SLACK][n] for
                n in 1:num_hydros
            ) +
            sum(hydros[n].spillage_penalty * m[SPILLAGE][n] for n in 1:num_hydros)
    )
end