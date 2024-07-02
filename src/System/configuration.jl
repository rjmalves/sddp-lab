
# CLASS Configuration -----------------------------------------------------------------------

struct Configuration
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
end

function Configuration(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_configuration_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_configuration_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_configuration_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_configuration_consistency!(d, e)

    return if valid_consistency
        Configuration(d["buses"], d["lines"], d["hydros"], d["thermals"])
    else
        nothing
    end
end

function Configuration(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_configuration_internals_from_files!(d, e)

    return valid ? Configuration(d, e) : nothing
end

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, c::Configuration)
    add_system_elements!(m, c.buses)
    add_system_elements!(m, c.lines)
    add_system_elements!(m, c.hydros)
    add_system_elements!(m, c.thermals)
    return true
end