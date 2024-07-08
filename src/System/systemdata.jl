
# CLASS SystemData -----------------------------------------------------------------------

struct SystemData <: InputModule
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
end

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

# SDDP METHODS -----------------------------------------------------------------------------

function add_system_elements!(m::JuMP.Model, s::SystemData)
    add_system_elements!(m, s.buses)
    add_system_elements!(m, s.lines)
    add_system_elements!(m, s.hydros)
    add_system_elements!(m, s.thermals)
    return true
end
