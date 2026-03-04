# System Configuration

The system configuration defines the physical power system: buses (load nodes),
transmission lines, hydro plants, thermal plants, non-controllable generators,
energy contracts, and pumping stations. It is specified in `system.jsonc` within
the study's `data/` directory.

## Top-Level Structure

```jsonc
{
    // Required sections
    "buses": { ... },
    "lines": { ... },
    "hydros": { ... },
    "thermals": { ... },
    // Optional sections (omit if not needed)
    "noncontrollables": { ... },
    "energycontracts": { ... },
    "pumpingstations": { ... }
}
```

Each section uses the `file` reference pattern: a `"file"` key pointing to a CSV
file and an optional `"default_values"` dictionary for filling missing columns.

```jsonc
{
  "buses": {
    "file": "buses.csv",
    "default_values": {
      "deficit_cost": 1000.0,
    },
  },
}
```

The `default_values` dictionary provides fallback values for any CSV column that
is missing or contains an empty cell for a given row. Column names in the CSV must
match the field names listed below exactly.

## Buses

Buses represent load nodes in the power system. Each bus has a load deficit cost
that penalizes unserved demand.

### CSV Columns

| Column         | Type    | Required | Constraints                               | Description                           |
| -------------- | ------- | -------- | ----------------------------------------- | ------------------------------------- |
| `id`           | Integer | Yes      | > 0                                       | Unique bus identifier                 |
| `name`         | String  | Yes      | Non-empty, alphanumeric/hyphen/underscore | Human-readable name                   |
| `deficit_cost` | Real    | Yes      | > 0                                       | Cost per MW of unserved load (\$/MWh) |

### Constraints

- All `id` values must be unique across buses.
- All `name` values must be unique across buses.
- Names must match the pattern `^[\sa-zA-Z0-9_-]*$`.

### Example

**`system.jsonc` (buses section):**

```jsonc
{
  "buses": {
    "file": "buses.csv",
    "default_values": {
      "deficit_cost": 1000.0,
    },
  },
}
```

**`buses.csv`:**

```csv
id,name,deficit_cost
1,"North",500.0
2,"South",750.0
```

## Lines

Lines represent transmission interconnections between two buses. Power flow is
bounded by the line capacity, and an exchange penalty cost can be applied to
discourage unnecessary transfers.

### CSV Columns

| Column             | Type    | Required | Constraints             | Description                              |
| ------------------ | ------- | -------- | ----------------------- | ---------------------------------------- |
| `id`               | Integer | Yes      | > 0                     | Unique line identifier                   |
| `name`             | String  | Yes      | Non-empty, alphanumeric | Human-readable name                      |
| `source_bus_id`    | Integer | Yes      | Valid bus id            | Source bus reference                     |
| `target_bus_id`    | Integer | Yes      | Valid bus id            | Target bus reference                     |
| `capacity`         | Real    | Yes      | > 0                     | Maximum power flow (MW)                  |
| `exchange_penalty` | Real    | Yes      | --                      | Penalty cost per MW transferred (\$/MWh) |

### Constraints

- All `id` values must be unique across lines.
- All `name` values must be unique across lines.
- Both `source_bus_id` and `target_bus_id` must reference existing bus ids.

### Example

**`system.jsonc` (lines section):**

```jsonc
{
  "lines": {
    "file": "lines.csv",
    "default_values": {
      "exchange_penalty": 0.01,
    },
  },
}
```

**`lines.csv`:**

```csv
id,name,source_bus_id,target_bus_id,capacity,exchange_penalty
1,"North-South",1,2,500.0,0.01
```

!!! note
A study with a single bus can have an empty lines CSV (header row only, no
data rows).

## Hydros

Hydro plants are the core state variables in SDDP. Each plant has a reservoir
with storage bounds, generation limits, a productivity factor converting water
flow to power, and a spillage penalty.

### CSV Columns

| Column             | Type    | Required | Constraints             | Description                                |
| ------------------ | ------- | -------- | ----------------------- | ------------------------------------------ |
| `id`               | Integer | Yes      | > 0                     | Unique hydro identifier                    |
| `downstream_id`    | Integer | Yes      | >= 0                    | Id of downstream hydro (0 = no downstream) |
| `name`             | String  | Yes      | Non-empty, alphanumeric | Human-readable name                        |
| `bus_id`           | Integer | Yes      | Valid bus id            | Bus where generation is injected           |
| `productivity`     | Real    | Yes      | >= 0                    | Conversion factor: MW per (m3/s)           |
| `initial_storage`  | Real    | Yes      | >= 0                    | Starting reservoir volume (hm3)            |
| `min_storage`      | Real    | Yes      | >= 0                    | Minimum reservoir volume (hm3)             |
| `max_storage`      | Real    | Yes      | >= 0                    | Maximum reservoir volume (hm3)             |
| `min_generation`   | Real    | Yes      | >= 0                    | Minimum power output (MW)                  |
| `max_generation`   | Real    | Yes      | >= 0                    | Maximum power output (MW)                  |
| `spillage_penalty` | Real    | Yes      | >= 0                    | Cost per unit of spilled water (\$/m3/s)   |

### Constraints

- All `id` values must be unique across hydros.
- All `name` values must be unique across hydros.
- `bus_id` must reference an existing bus.
- `min_storage <= initial_storage <= max_storage`.
- `min_generation <= max_generation`.
- The downstream topology formed by `downstream_id` references must be a
  directed acyclic graph (DAG). Set `downstream_id` to `0` for plants with
  no downstream connection.

### Example

**`system.jsonc` (hydros section):**

```jsonc
{
  "hydros": {
    "file": "hydros.csv",
    "default_values": {
      "downstream_id": 0,
      "productivity": 1.0,
      "spillage_penalty": 0.01,
    },
  },
}
```

**`hydros.csv`:**

```csv
id,name,downstream_id,bus_id,productivity,initial_storage,min_storage,max_storage,min_generation,max_generation,spillage_penalty
1,"UHE1",0,1,1.0,83.22,0.0,100.0,0.0,60.0,0.01
2,"UHE2",1,1,0.8,50.0,10.0,80.0,0.0,40.0,0.01
```

In this example, UHE2 is upstream of UHE1 (`downstream_id = 1`), so water
released from UHE2 flows into UHE1's reservoir.

## Thermals

Thermal plants provide dispatchable generation at a fixed marginal cost.

### CSV Columns

| Column           | Type    | Required | Constraints             | Description                       |
| ---------------- | ------- | -------- | ----------------------- | --------------------------------- |
| `id`             | Integer | Yes      | > 0                     | Unique thermal identifier         |
| `name`           | String  | Yes      | Non-empty, alphanumeric | Human-readable name               |
| `bus_id`         | Integer | Yes      | Valid bus id            | Bus where generation is injected  |
| `min_generation` | Real    | Yes      | >= 0                    | Minimum power output (MW)         |
| `max_generation` | Real    | Yes      | >= 0                    | Maximum power output (MW)         |
| `cost`           | Real    | Yes      | >= 0                    | Marginal generation cost (\$/MWh) |

### Constraints

- All `id` values must be unique across thermals.
- All `name` values must be unique across thermals.
- `bus_id` must reference an existing bus.
- `min_generation <= max_generation`.

### Example

**`thermals.csv`:**

```csv
id,name,bus_id,min_generation,max_generation,cost
1,"UTE1",1,0.0,15.0,5.0
2,"UTE2",1,0.0,15.0,10.0
```

## Non-Controllable Generation

Non-controllable generators represent renewable or must-run generation sources
(e.g., wind, solar, run-of-river). They inject power at their maximum capacity
by default; the optimizer may curtail generation at a specified cost.

### CSV Columns

| Column             | Type    | Required | Constraints             | Description                                  |
| ------------------ | ------- | -------- | ----------------------- | -------------------------------------------- |
| `id`               | Integer | Yes      | > 0                     | Unique identifier                            |
| `name`             | String  | Yes      | Non-empty, alphanumeric | Human-readable name                          |
| `bus_id`           | Integer | Yes      | Valid bus id            | Bus where generation is injected             |
| `max_generation`   | Real    | Yes      | >= 0                    | Maximum (nameplate) generation (MW)          |
| `curtailment_cost` | Real    | Yes      | >= 0                    | Cost per MW of curtailed generation (\$/MWh) |

### Constraints

- All `id` values must be unique across non-controllables.
- All `name` values must be unique across non-controllables.
- `bus_id` must reference an existing bus.

### Modeling

The non-controllable generator injects up to `max_generation` MW into its bus.
The SDDP subproblem introduces a curtailment variable bounded by `[0, max_generation]`
with cost `curtailment_cost` in the objective. This means the optimizer will only
curtail generation when it is cheaper than alternatives (e.g., when there is
excess supply).

### Example

**`system.jsonc` (noncontrollables section):**

```jsonc
{
  "noncontrollables": {
    "file": "noncontrollables.csv",
    "default_values": {
      "curtailment_cost": 0.0,
    },
  },
}
```

**`noncontrollables.csv`:**

```csv
id,name,bus_id,max_generation,curtailment_cost
1,"WindFarm1",1,50.0,0.5
2,"Solar1",2,30.0,0.0
```

!!! note
This section is optional. If omitted from `system.jsonc`, no non-controllable
generators are included in the model.

## Energy Contracts

Energy contracts model bilateral purchase (import) or sale (export) agreements at
a fixed price, subject to minimum and maximum power limits.

### JSONC Structure

Unlike the simpler CSV-only entities, energy contracts use a nested structure in
the CSV with a `type` field and a `limits` sub-object.

### CSV Columns

| Column          | Type    | Required | Constraints              | Description                         |
| --------------- | ------- | -------- | ------------------------ | ----------------------------------- |
| `id`            | Integer | Yes      | > 0                      | Unique contract identifier          |
| `name`          | String  | Yes      | Non-empty, alphanumeric  | Human-readable name                 |
| `bus_id`        | Integer | Yes      | Valid bus id             | Bus where the contract is connected |
| `type`          | String  | Yes      | `"import"` or `"export"` | Contract direction                  |
| `price_per_mwh` | Real    | Yes      | --                       | Contract price (\$/MWh)             |

Additionally, a `limits` sub-object is required in the JSONC entity definition:

| Field    | Type | Required | Constraints | Description        |
| -------- | ---- | -------- | ----------- | ------------------ |
| `min_mw` | Real | Yes      | >= 0        | Minimum power (MW) |
| `max_mw` | Real | Yes      | >= 0        | Maximum power (MW) |

### Constraints

- All `id` values must be unique across energy contracts.
- All `name` values must be unique across energy contracts.
- `bus_id` must reference an existing bus.
- `type` must be exactly `"import"` or `"export"`.
- `min_mw <= max_mw`.

### Modeling

- An **import** contract adds generation to the bus at the contract price (a cost
  in the objective).
- An **export** contract removes generation from the bus; the contract price appears
  as negative cost (revenue) in the objective.

### Example

**`system.jsonc` (energycontracts section):**

```jsonc
{
  "energycontracts": {
    "entities": [
      {
        "id": 1,
        "name": "ImportContract1",
        "bus_id": 1,
        "type": "import",
        "price_per_mwh": 120.0,
        "limits": {
          "min_mw": 0.0,
          "max_mw": 50.0,
        },
      },
      {
        "id": 2,
        "name": "ExportContract1",
        "bus_id": 1,
        "type": "export",
        "price_per_mwh": 80.0,
        "limits": {
          "min_mw": 0.0,
          "max_mw": 30.0,
        },
      },
    ],
  },
}
```

!!! note
This section is optional. If omitted from `system.jsonc`, no energy contracts
are included in the model.

## Pumping Stations

Pumping stations transfer water between two hydro reservoirs at the cost of
electrical power consumption. They model inter-basin water transfers and
pump-storage operations.

### JSONC Structure

Pumping stations reference two hydro plants (source and destination) and include
a `flow` sub-object for flow limits.

### Fields

| Field                    | Type    | Required | Constraints             | Description                                        |
| ------------------------ | ------- | -------- | ----------------------- | -------------------------------------------------- |
| `id`                     | Integer | Yes      | > 0                     | Unique pumping station identifier                  |
| `name`                   | String  | Yes      | Non-empty, alphanumeric | Human-readable name                                |
| `bus_id`                 | Integer | Yes      | Valid bus id            | Bus where power is consumed                        |
| `source_hydro_id`        | Integer | Yes      | Valid hydro id          | Hydro plant water is pumped from                   |
| `destination_hydro_id`   | Integer | Yes      | Valid hydro id          | Hydro plant water is pumped to                     |
| `consumption_mw_per_m3s` | Real    | Yes      | > 0                     | Power consumed per unit of pumped flow (MW/(m3/s)) |

Additionally, a `flow` sub-object is required:

| Field     | Type | Required | Constraints | Description                 |
| --------- | ---- | -------- | ----------- | --------------------------- |
| `min_m3s` | Real | Yes      | >= 0        | Minimum pumping flow (m3/s) |
| `max_m3s` | Real | Yes      | >= 0        | Maximum pumping flow (m3/s) |

### Constraints

- All `id` values must be unique across pumping stations.
- All `name` values must be unique across pumping stations.
- `bus_id` must reference an existing bus.
- Both `source_hydro_id` and `destination_hydro_id` must reference existing hydro ids.
- `source_hydro_id` and `destination_hydro_id` must be different.
- `min_m3s <= max_m3s`.

### Modeling

When a pumping station operates at flow rate `q` (m3/s), it:

1. **Removes** `q` from the source hydro's reservoir balance (equivalent to outflow).
2. **Adds** `q` to the destination hydro's reservoir balance (equivalent to inflow).
3. **Consumes** `q * consumption_mw_per_m3s` MW of power from the connected bus.

### Example

**`system.jsonc` (pumpingstations section):**

```jsonc
{
  "pumpingstations": {
    "entities": [
      {
        "id": 1,
        "name": "Pump1",
        "bus_id": 1,
        "source_hydro_id": 2,
        "destination_hydro_id": 1,
        "consumption_mw_per_m3s": 0.5,
        "flow": {
          "min_m3s": 0.0,
          "max_m3s": 20.0,
        },
      },
    ],
  },
}
```

!!! note
This section is optional. If omitted from `system.jsonc`, no pumping stations
are included in the model.

## Complete System Example

A complete `system.jsonc` combining all entity types:

```jsonc
{
  "buses": {
    "file": "buses.csv",
    "default_values": {
      "deficit_cost": 1000.0,
    },
  },
  "lines": {
    "file": "lines.csv",
    "default_values": {
      "exchange_penalty": 0.01,
    },
  },
  "hydros": {
    "file": "hydros.csv",
    "default_values": {
      "downstream_id": 0,
      "productivity": 1.0,
      "spillage_penalty": 0.01,
    },
  },
  "thermals": {
    "file": "thermals.csv",
    "default_values": {},
  },
  "noncontrollables": {
    "file": "noncontrollables.csv",
    "default_values": {
      "curtailment_cost": 0.0,
    },
  },
  "energycontracts": {
    "entities": [
      {
        "id": 1,
        "name": "ImportContract",
        "bus_id": 1,
        "type": "import",
        "price_per_mwh": 120.0,
        "limits": { "min_mw": 0.0, "max_mw": 50.0 },
      },
    ],
  },
  "pumpingstations": {
    "entities": [
      {
        "id": 1,
        "name": "Pump1",
        "bus_id": 1,
        "source_hydro_id": 2,
        "destination_hydro_id": 1,
        "consumption_mw_per_m3s": 0.5,
        "flow": { "min_m3s": 0.0, "max_m3s": 20.0 },
      },
    ],
  },
}
```
