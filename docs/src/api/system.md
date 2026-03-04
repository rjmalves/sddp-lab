# System Elements

The system module defines all physical power system components. These types are
constructed automatically from your `system.jsonc` configuration file and are
available through the [`SystemData`](@ref) container.

## System Container

```@docs
SystemData
```

## Accessing System Data

```@docs
get_system
get_buses
get_buses_entities
get_hydros
get_hydros_entities
get_thermals
get_thermals_entities
get_lines
get_lines_entities
get_noncontrollables
get_noncontrollables_entities
get_energycontracts
get_energycontracts_entities
get_pumpingstations
get_pumpingstations_entities
```

## Entity Collections

```@docs
Buses
Lines
Hydros
Thermals
NonControllables
EnergyContracts
PumpingStations
```

## Individual Entities

```@docs
Bus
Line
Hydro
Thermal
NonControllable
EnergyContract
PumpingStation
```

## Cascade Topology

```@docs
upstream
downstream
get_ids
```

## Base Types

```@docs
SystemEntity
SystemEntitySet
```
