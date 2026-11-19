# System Configuration

The system configuration defines the physical power system: buses (load nodes),
transmission lines, hydro plants, and thermal plants. It is specified in
`system.jsonc` within the study's `data/` directory.

## Top-Level Structure

```jsonc
{
    // Required sections
    "buses": { ... },
    "lines": { ... },
    "hydros": { ... },
    "thermals": { ... }
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
}
```
