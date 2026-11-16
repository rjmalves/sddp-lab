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
```

## Entity Collections

```@docs
Buses
Lines
Hydros
Thermals
```

## Individual Entities

```@docs
Bus
Line
Hydro
Thermal
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
