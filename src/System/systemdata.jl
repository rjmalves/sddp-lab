
# CLASS SystemData -----------------------------------------------------------------------

function SystemData(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_system_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_system_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_system_content!(d, e)
    valid_consistency = valid_content && __validate_system_consistency!(d, e)

    return if valid_consistency
        SystemData(d["buses"], d["lines"], d["hydros"], d["thermals"])
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
    get_system(files) -> SystemData

Extract the [`SystemData`](@ref) module from an `InputModule` vector.
"""
function get_system(f::Vector{InputModule})::SystemData
    return get_input_module(f, SystemData)
end

"""
    get_hydros(s) -> Hydros

Return the [`Hydros`](@ref) collection from a [`SystemData`](@ref) instance.
"""
function get_hydros(s::SystemData)::Hydros
    return s.hydros
end

"""
    get_hydros_entities(s) -> Vector{Hydro}

Return the vector of [`Hydro`](@ref) entities from a [`SystemData`](@ref) instance.
"""
function get_hydros_entities(s::SystemData)::Vector{Hydro}
    return s.hydros.entities
end

"""
    get_buses(s) -> Buses

Return the [`Buses`](@ref) collection from a [`SystemData`](@ref) instance.
"""
function get_buses(s::SystemData)::Buses
    return s.buses
end

"""
    get_buses_entities(s) -> Vector{Bus}

Return the vector of [`Bus`](@ref) entities from a [`SystemData`](@ref) instance.
"""
function get_buses_entities(s::SystemData)::Vector{Bus}
    return s.buses.entities
end

"""
    get_thermals(s) -> Thermals

Return the [`Thermals`](@ref) collection from a [`SystemData`](@ref) instance.
"""
function get_thermals(s::SystemData)::Thermals
    return s.thermals
end

"""
    get_thermals_entities(s) -> Vector{Thermal}

Return the vector of [`Thermal`](@ref) entities from a [`SystemData`](@ref) instance.
"""
function get_thermals_entities(s::SystemData)::Vector{Thermal}
    return s.thermals.entities
end

"""
    get_lines(s) -> Lines

Return the [`Lines`](@ref) collection from a [`SystemData`](@ref) instance.
"""
function get_lines(s::SystemData)::Lines
    return s.lines
end

"""
    get_lines_entities(s) -> Vector{Line}

Return the vector of [`Line`](@ref) entities from a [`SystemData`](@ref) instance.
"""
function get_lines_entities(s::SystemData)::Vector{Line}
    return s.lines.entities
end
