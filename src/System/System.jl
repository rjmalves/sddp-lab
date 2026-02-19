module System

using JSON
using CSV
using DataFrames
using Graphs

using ..Lab
using ..Utils

import Base: length

# TYPES ------------------------------------------------------------------------

"""
    SystemEntity

Abstract base type for all physical power system components (buses, hydros,
thermals, etc.). Every concrete entity type provides `get_id` and `get_params`
methods.
"""
abstract type SystemEntity end

"""
    Bus <: SystemEntity

Represents a load bus (electrical node) in the power system.

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `deficit_cost`: Penalty cost for unserved energy at this bus (currency/MWh).

See also: [`Buses`](@ref), [`get_buses`](@ref)
"""
struct Bus <: SystemEntity
    id::Integer
    name::String
    deficit_cost::Real
end

"""
    Line <: SystemEntity

Represents a transmission line connecting two buses.

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `source_bus_id`: ID of the sending-end bus.
- `target_bus_id`: ID of the receiving-end bus.
- `capacity`: Maximum power flow capacity (MW).
- `exchange_penalty`: Penalty cost per MW of exchange (currency/MWh).
- `source_bus`: Reference to the [`Bus`](@ref) at the source end.
- `target_bus`: Reference to the [`Bus`](@ref) at the target end.

See also: [`Lines`](@ref), [`get_lines`](@ref)
"""
struct Line <: SystemEntity
    id::Integer
    name::String
    source_bus_id::Integer
    target_bus_id::Integer
    capacity::Real
    exchange_penalty::Real
    # References to other system elements
    source_bus::Ref{Bus}
    target_bus::Ref{Bus}
end

"""
    Hydro <: SystemEntity

Represents a hydro power plant with reservoir storage.

# Fields
- `id`: Unique integer identifier.
- `downstream_id`: ID of the immediately downstream hydro (0 = none).
- `name`: Human-readable name.
- `bus_id`: ID of the bus to which this plant is connected.
- `productivity`: Power conversion factor (MW·s/hm³).
- `initial_storage`: Reservoir storage at the start of the horizon (hm³).
- `min_storage`: Minimum operational storage (hm³).
- `max_storage`: Maximum reservoir capacity (hm³).
- `min_generation`: Minimum turbine generation (MW).
- `max_generation`: Maximum turbine generation / installed capacity (MW).
- `spillage_penalty`: Penalty cost for spilling water (currency/m³).
- `bus`: Reference to the connected [`Bus`](@ref).

See also: [`Hydros`](@ref), [`get_hydros`](@ref), [`upstream`](@ref),
[`downstream`](@ref)
"""
struct Hydro <: SystemEntity
    id::Integer
    downstream_id::Integer
    name::String
    bus_id::Integer
    productivity::Real
    initial_storage::Real
    min_storage::Real
    max_storage::Real
    min_generation::Real
    max_generation::Real
    spillage_penalty::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

"""
    Thermal <: SystemEntity

Represents a thermal power plant (gas, coal, nuclear, etc.).

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `bus_id`: ID of the bus to which this plant is connected.
- `min_generation`: Minimum output when committed (MW).
- `max_generation`: Installed / maximum output capacity (MW).
- `cost`: Variable generation cost (currency/MWh).
- `bus`: Reference to the connected [`Bus`](@ref).

See also: [`Thermals`](@ref), [`get_thermals`](@ref)
"""
struct Thermal <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    min_generation::Real
    max_generation::Real
    cost::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

"""
    NonControllable <: SystemEntity

Represents a non-controllable (renewable) generation source such as wind or
solar PV. The plant has a time-varying maximum generation profile and a
curtailment penalty when its output is reduced below available capacity.

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `bus_id`: ID of the bus to which this source is connected.
- `max_generation`: Installed capacity / maximum available generation (MW).
- `curtailment_cost`: Penalty cost per MW of curtailed generation (currency/MWh).
- `bus`: Reference to the connected [`Bus`](@ref).

See also: [`NonControllables`](@ref), [`get_noncontrollables`](@ref)
"""
struct NonControllable <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    max_generation::Real
    curtailment_cost::Real
    # Reference to other system elements
    bus::Ref{Bus}
end

"""
    EnergyContract <: SystemEntity

Represents a bilateral energy contract for importing or exporting power.

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `bus_id`: ID of the bus associated with this contract.
- `contract_type`: `"import"` (power received) or `"export"` (power delivered).
- `price_per_mwh`: Contract price (currency/MWh); positive = cost for imports.
- `min_mw`: Minimum contracted power (MW).
- `max_mw`: Maximum contracted power (MW).
- `bus`: Reference to the connected [`Bus`](@ref).

See also: [`EnergyContracts`](@ref), [`get_energycontracts`](@ref)
"""
struct EnergyContract <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    contract_type::String   # "import" or "export"
    price_per_mwh::Real
    min_mw::Real
    max_mw::Real
    bus::Ref{Bus}
end

"""
    PumpingStation <: SystemEntity

Represents a pumped-storage facility that transfers water from a source
reservoir to a destination reservoir, consuming electrical power.

# Fields
- `id`: Unique integer identifier.
- `name`: Human-readable name.
- `bus_id`: ID of the bus where power is consumed.
- `source_hydro_id`: ID of the hydro reservoir from which water is pumped.
- `destination_hydro_id`: ID of the hydro reservoir to which water is pumped.
- `consumption_mw_per_m3s`: Power consumed per unit pumped flow (MW·s/m³).
- `min_m3s`: Minimum pumping flow rate (m³/s).
- `max_m3s`: Maximum pumping flow rate (m³/s).
- `bus`: Reference to the connected [`Bus`](@ref).

See also: [`PumpingStations`](@ref), [`get_pumpingstations`](@ref)
"""
struct PumpingStation <: SystemEntity
    id::Integer
    name::String
    bus_id::Integer
    source_hydro_id::Integer
    destination_hydro_id::Integer
    consumption_mw_per_m3s::Real
    min_m3s::Real
    max_m3s::Real
    bus::Ref{Bus}
end

"""
    SystemEntitySet

Abstract base type for collections of [`SystemEntity`](@ref) objects. Provides
`get_ids`, `length`, and `get_params_df` methods.
"""
abstract type SystemEntitySet end

"""
    Buses <: SystemEntitySet

Collection of all [`Bus`](@ref) entities in the power system.

# Fields
- `entities`: Vector of [`Bus`](@ref) objects.

See also: [`get_buses`](@ref), [`get_buses_entities`](@ref)
"""
struct Buses <: SystemEntitySet
    entities::Vector{Bus}
end

"""
    Lines <: SystemEntitySet

Collection of all [`Line`](@ref) entities (transmission lines) in the system.

# Fields
- `entities`: Vector of [`Line`](@ref) objects.

See also: [`get_lines`](@ref), [`get_lines_entities`](@ref)
"""
struct Lines <: SystemEntitySet
    entities::Vector{Line}
end

"""
    Hydros <: SystemEntitySet

Collection of all [`Hydro`](@ref) plant entities, along with the directed
cascade topology graph.

# Fields
- `entities`: Vector of [`Hydro`](@ref) objects.
- `topology`: Directed graph (`DiGraph`) encoding upstream/downstream
  relationships; node indices correspond to hydro IDs.

See also: [`get_hydros`](@ref), [`upstream`](@ref), [`downstream`](@ref)
"""
struct Hydros <: SystemEntitySet
    entities::Vector{Hydro}
    topology::DiGraph
end

"""
    Thermals <: SystemEntitySet

Collection of all [`Thermal`](@ref) plant entities in the system.

# Fields
- `entities`: Vector of [`Thermal`](@ref) objects.

See also: [`get_thermals`](@ref), [`get_thermals_entities`](@ref)
"""
struct Thermals <: SystemEntitySet
    entities::Vector{Thermal}
end

"""
    NonControllables <: SystemEntitySet

Collection of all [`NonControllable`](@ref) (renewable) generation entities.

# Fields
- `entities`: Vector of [`NonControllable`](@ref) objects.

See also: [`get_noncontrollables`](@ref), [`get_noncontrollables_entities`](@ref)
"""
struct NonControllables <: SystemEntitySet
    entities::Vector{NonControllable}
end

"""
    EnergyContracts <: SystemEntitySet

Collection of all [`EnergyContract`](@ref) entities in the system.

# Fields
- `entities`: Vector of [`EnergyContract`](@ref) objects.

See also: [`get_energycontracts`](@ref), [`get_energycontracts_entities`](@ref)
"""
struct EnergyContracts <: SystemEntitySet
    entities::Vector{EnergyContract}
end

"""
    PumpingStations <: SystemEntitySet

Collection of all [`PumpingStation`](@ref) entities in the system.

# Fields
- `entities`: Vector of [`PumpingStation`](@ref) objects.

See also: [`get_pumpingstations`](@ref), [`get_pumpingstations_entities`](@ref)
"""
struct PumpingStations <: SystemEntitySet
    entities::Vector{PumpingStation}
end

"""
    SystemData <: InputModule

Root container for all power system topology and component data. Produced by
parsing the `system.jsonc` file referenced in `main.jsonc`.

# Fields
- `buses`: [`Buses`](@ref) collection.
- `lines`: [`Lines`](@ref) collection.
- `hydros`: [`Hydros`](@ref) collection (includes cascade topology).
- `thermals`: [`Thermals`](@ref) collection.
- `noncontrollables`: [`NonControllables`](@ref) collection.
- `energycontracts`: [`EnergyContracts`](@ref) collection.
- `pumpingstations`: [`PumpingStations`](@ref) collection.

See also: [`get_system`](@ref), [`get_buses`](@ref), [`get_hydros`](@ref)
"""
struct SystemData <: InputModule
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
    noncontrollables::NonControllables
    energycontracts::EnergyContracts
    pumpingstations::PumpingStations
end

# GENERAL METHODS ------------------------------------------------------------------------

"""
    get_id(se) -> Integer

Return the unique integer ID of a [`SystemEntity`](@ref).
"""
function get_id(se::SystemEntity)::Integer end

"""
    get_params(se) -> Dict{String,Any}

Return a dictionary of entity-specific parameters for a [`SystemEntity`](@ref).
"""
function get_params(se::SystemEntity)::Dict{String,Any} end

"""
    get_ids(ses) -> Vector{Integer}

Return a vector of unique integer IDs for all entities in a
[`SystemEntitySet`](@ref).
"""
function get_ids(ses::SystemEntitySet)::Vector{Integer} end

"""
    length(ses::SystemEntitySet) -> Integer

Return the number of entities in a [`SystemEntitySet`](@ref).
"""
function length(ses::SystemEntitySet)::Integer end

"""
    get_params_df(ses) -> DataFrame

Return the parameters of all entities in a [`SystemEntitySet`](@ref) as a
`DataFrame`, with one row per entity.
"""
function get_params_df(ses::SystemEntitySet)::DataFrame end

# UTILS ------------------------------------------------------------------------

function __cast_system_entity_from_file!(d::Dict{String,Any}, e::CompositeException)::Bool
    df = read_csv(d["file"], e)
    valid_df = df !== nothing
    internal_d = valid_df ? __dataframe_to_dict(df) : nothing
    valid_file_data = internal_d !== nothing
    if valid_file_data
        d["entities"] = internal_d
    end
    return valid_file_data
end

function __validate_system_entity_file_key!(d::Dict{String,Any}, e::CompositeException)
    has_file_key = haskey(d, "file")
    valid_file_key = has_file_key && __validate_key_types!(d, ["file"], [String], e)
    return valid_file_key
end

function __fill_default_values!(
    entities::Vector{Dict{String,Any}}, default_values::Dict{String,Any}
)
    for e in entities
        for (k, v) in e
            if v === missing
                e[k] = default_values[k]
            end
        end
    end
end

function __fill_system_entity_default_values!(d::Dict{String,Any}, e::CompositeException)
    entities = d["entities"]
    default_values = haskey(d, "default_values") ? d["default_values"] : Dict{String,Any}()
    valid = __validate_required_default_values!(d["entities"], default_values, e)
    !valid || __fill_default_values!(entities, default_values)
    return nothing
end

function __cast_system_entities_content!(
    d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    entities_d = d[key]
    should_cast_from_file = __validate_system_entity_file_key!(entities_d, e)

    valid = !should_cast_from_file
    if should_cast_from_file
        valid = __cast_system_entity_from_file!(entities_d, e)
    end

    if valid
        # When entities are defined inline in JSONC (not from CSV), the JSON parser
        # produces Vector{Any} instead of Vector{Dict{String,Any}}. Convert here so
        # that downstream validators receive the expected concrete type.
        if haskey(entities_d, "entities") && entities_d["entities"] isa Vector{Any}
            entities_d["entities"] = convert(
                Vector{Dict{String,Any}},
                [convert(Dict{String,Any}, x) for x in entities_d["entities"]],
            )
        end
        __fill_system_entity_default_values!(entities_d, e)
    end

    return valid
end

# INTERNALS ------------------------------------------------------------------------

include("bus-validators.jl")
include("bus.jl")

include("line-validators.jl")
include("line.jl")

include("hydro-validators.jl")
include("hydro.jl")

include("thermal-validators.jl")
include("thermal.jl")

include("noncontrollable-validators.jl")
include("noncontrollable.jl")

include("energycontract-validators.jl")
include("energycontract.jl")

include("pumpingstation-validators.jl")
include("pumpingstation.jl")

include("systemdata-validators.jl")
include("systemdata.jl")

export SystemData,
    SystemEntity,
    SystemEntitySet,
    Hydro,
    Hydros,
    Bus,
    Buses,
    Thermal,
    Thermals,
    NonControllable,
    NonControllables,
    EnergyContract,
    EnergyContracts,
    PumpingStation,
    PumpingStations,
    Line,
    Lines,
    get_system,
    get_buses,
    get_buses_entities,
    get_hydros,
    get_hydros_entities,
    get_thermals,
    get_thermals_entities,
    get_noncontrollables,
    get_noncontrollables_entities,
    get_energycontracts,
    get_energycontracts_entities,
    get_pumpingstations,
    get_pumpingstations_entities,
    get_lines,
    get_lines_entities,
    get_ids,
    downstream,
    upstream

end
