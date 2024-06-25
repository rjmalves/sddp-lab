
# CLASS Configuration -----------------------------------------------------------------------

struct Configuration
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
end

function Configuration(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    d["buses"] = Buses(d["buses"], e)
    d["lines"] = Lines(d["lines"], d["buses"], e)
    d["hydros"] = Hydros(d["hydros"], d["buses"], e)
    d["thermals"] = Thermals(d["thermals"], d["buses"], e)

    # Keys and types validation
    valid = __validate_configuration_keys_types!(d, e)

    return if valid
        Configuration(d["buses"], d["lines"], d["hydros"], d["thermals"])
    else
        nothing
    end
end

function Configuration(filename::String, e::CompositeException)
    d = read_jsonc(filename)

    # Content validation and casting for internals that depend on files
    valid_buses = __validate_cast_buses_content!(d, e)
    valid_lines = __validate_cast_lines_content!(d, e)
    valid_hydros = __validate_cast_hydros_content!(d, e)
    valid_thermals = __validate_cast_thermals_content!(d, e)

    valid = valid_buses && valid_lines && valid_hydros && valid_thermals

    return valid ? Configuration(d, e) : nothing
end
