
# CLASS Configuration -----------------------------------------------------------------------

struct Configuration
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
end

function Configuration(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    d["buses"] = Buses(d["buses"]["entities"], e)
    d["lines"] = Lines(d["lines"]["entities"], d["buses"], e)
    d["hydros"] = Hydros(d["hydros"]["entities"], d["buses"], e)
    d["thermals"] = Thermals(d["thermals"]["entities"], d["buses"], e)

    # Keys and types validation
    valid = __validate_configuration_keys_types!(d, e)

    return if valid
        Configuration(d["buses"], d["lines"], d["hydros"], d["thermals"])
    else
        nothing
    end
end

function Configuration(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Content validation and casting for internals that depend on files
    valid_buses = valid_jsonc && __validate_cast_buses_content!(d, e)
    valid_lines = valid_jsonc && __validate_cast_lines_content!(d, e)
    valid_hydros = valid_jsonc && __validate_cast_hydros_content!(d, e)
    valid_thermals = valid_jsonc && __validate_cast_thermals_content!(d, e)

    valid = valid_buses && valid_lines && valid_hydros && valid_thermals

    return valid ? Configuration(d, e) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, c::Configuration)
    add_system_elements!(m, c.buses)
    add_system_elements!(m, c.lines)
    add_system_elements!(m, c.hydros)
    return add_system_elements!(m, c.thermals)
end