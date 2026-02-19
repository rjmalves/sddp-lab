
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
    get_system(files) -> SystemData

Extract the [`SystemData`](@ref) module from an `InputModule` vector.

# Arguments
- `files`: Vector of [`InputModule`](@ref) instances loaded from disk.
"""
function get_system(f::Vector{InputModule})::SystemData
    return get_input_module(f, SystemData)
end

"""
    get_hydros(s) -> Hydros

Return the [`Hydros`](@ref) collection from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_hydros(s::SystemData)::Hydros
    return s.hydros
end

"""
    get_hydros_entities(s) -> Vector{Hydro}

Return the vector of [`Hydro`](@ref) entities from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_hydros_entities(s::SystemData)::Vector{Hydro}
    return s.hydros.entities
end

"""
    get_buses(s) -> Buses

Return the [`Buses`](@ref) collection from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_buses(s::SystemData)::Buses
    return s.buses
end

"""
    get_buses_entities(s) -> Vector{Bus}

Return the vector of [`Bus`](@ref) entities from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_buses_entities(s::SystemData)::Vector{Bus}
    return s.buses.entities
end

"""
    get_thermals(s) -> Thermals

Return the [`Thermals`](@ref) collection from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_thermals(s::SystemData)::Thermals
    return s.thermals
end

"""
    get_thermals_entities(s) -> Vector{Thermal}

Return the vector of [`Thermal`](@ref) entities from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_thermals_entities(s::SystemData)::Vector{Thermal}
    return s.thermals.entities
end

"""
    get_lines(s) -> Lines

Return the [`Lines`](@ref) collection from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_lines(s::SystemData)::Lines
    return s.lines
end

"""
    get_lines_entities(s) -> Vector{Line}

Return the vector of [`Line`](@ref) entities from a [`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_lines_entities(s::SystemData)::Vector{Line}
    return s.lines.entities
end

"""
    get_noncontrollables(s) -> NonControllables

Return the [`NonControllables`](@ref) collection from a [`SystemData`](@ref)
instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_noncontrollables(s::SystemData)::NonControllables
    return s.noncontrollables
end

"""
    get_noncontrollables_entities(s) -> Vector{NonControllable}

Return the vector of [`NonControllable`](@ref) entities from a
[`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_noncontrollables_entities(s::SystemData)::Vector{NonControllable}
    return s.noncontrollables.entities
end

"""
    get_energycontracts(s) -> EnergyContracts

Return the [`EnergyContracts`](@ref) collection from a [`SystemData`](@ref)
instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_energycontracts(s::SystemData)::EnergyContracts
    return s.energycontracts
end

"""
    get_energycontracts_entities(s) -> Vector{EnergyContract}

Return the vector of [`EnergyContract`](@ref) entities from a
[`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_energycontracts_entities(s::SystemData)::Vector{EnergyContract}
    return s.energycontracts.entities
end

"""
    get_pumpingstations(s) -> PumpingStations

Return the [`PumpingStations`](@ref) collection from a [`SystemData`](@ref)
instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_pumpingstations(s::SystemData)::PumpingStations
    return s.pumpingstations
end

"""
    get_pumpingstations_entities(s) -> Vector{PumpingStation}

Return the vector of [`PumpingStation`](@ref) entities from a
[`SystemData`](@ref) instance.

# Arguments
- `s`: A [`SystemData`](@ref) object.
"""
function get_pumpingstations_entities(s::SystemData)::Vector{PumpingStation}
    return s.pumpingstations.entities
end
