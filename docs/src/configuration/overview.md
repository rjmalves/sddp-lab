# Configuration Overview

SDDPlab.jl is entirely configuration-driven. Users define studies through a hierarchy
of JSONC (JSON with comments) files that describe the power system, the stochastic
scenarios, the optimization engine, and optional constraints. This page explains the
file hierarchy, the common patterns used throughout, and provides a minimal working
example.

## File Hierarchy

Every study lives in a directory that contains a single entry point, `main.jsonc`.
This file references a `data/` subdirectory where all component configuration files
and CSV data files reside.

```
my_study/
  main.jsonc              # Entry point: engine config + file references
  data/
    system.jsonc          # Power system definition
    scenarios.jsonc       # Stochastic scenarios, graph, load, blocks, Markov
    constraints.jsonc     # Reserved for future constraints
    graph.jsonc           # Scenario graph (nodes and edges)
    inflow_scenarios.jsonc  # Inflow stochastic process parameters
    load.csv              # Deterministic load values
    buses.csv             # Bus entity data
    lines.csv             # Line entity data
    hydros.csv            # Hydro plant entity data
    thermals.csv          # Thermal plant entity data
```

### `main.jsonc`

The top-level file has two sections:

| Key      | Type   | Required | Description                                         |
| -------- | ------ | -------- | --------------------------------------------------- |
| `inputs` | Object | Yes      | Locates component config files within the data path |
| `engine` | Object | Yes      | Defines the optimization engine and all its options |

The `inputs` section specifies a `path` (relative directory) and a `files` map that
names the component configuration files:

```jsonc
{
  "inputs": {
    "path": "data",
    "files": {
      "scenarios": "scenarios.jsonc",
      "system": "system.jsonc",
      "constraints": "constraints.jsonc",
    },
  },
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      // ... engine configuration ...
    },
  },
}
```

!!! note
The `constraints.jsonc` file is currently reserved for future use. It should
exist but can be empty (an empty file or `{}`).

## The `kind` / `params` Pattern

Many configuration objects use a polymorphic dispatch pattern inspired by Julia's
type system. Instead of a flat dictionary, you specify a `kind` string (the exact
Julia type name) and a `params` dictionary with the parameters for that type:

```jsonc
{
  "kind": "CVaR",
  "params": {
    "alpha": 0.2,
    "lambda": 0.9,
  },
}
```

!!! warning
The `kind` field is **case-sensitive** and must match the exact Julia type name.
For example, `"CVaR"` is valid but `"cvar"` or `"CVAR"` will fail.

This pattern is used for:

- **Risk measures**: `Expectation`, `WorstCase`, `AVaR`, `CVaR`, `Entropic`, `WassersteinRM`, `ModifiedChiSquared`, `ConvexCombination`
- **Stopping criteria**: `IterationLimit`, `TimeLimit`, `LowerBoundStability`, `Statistical`, `SimulationStopping`, `FirstStageStopping`, `StoppingChain`
- **Parallel schemes**: `Serial`, `Threaded`, `Asynchronous`
- **Sampling schemes**: `DefaultSampling`, `InSampleMC`, `PSRSampling`
- **Duality handlers**: `DefaultDuality`, `ContinuousConicDualityHandler`, `StrengthenedConicDualityHandler`, `LagrangianDualityHandler`, `BanditDualityHandler`
- **Forward pass strategies**: `DefaultForwardPassStrategy`, `RevisitingForwardPassStrategy`, `RiskAdjustedForwardPassStrategy`, `RegularizedForwardPassStrategy`
- **Cut types**: `SingleCut`, `MultiCut`
- **Scaling modes**: `NoScaling`, `AutoScaling`
- **Inflow non-negativity**: `InflowNone`, `InflowPenalty`, `InflowTruncation`, `InflowTruncationWithPenalty`
- **Stochastic processes**: `Naive`, `AutoRegressive`, `VectorAutoRegressive`
- **Load formats**: `DeterministicLoad`
- **Engine**: `SDDPEngine`

For parameterless types (e.g. `Expectation`, `Serial`, `SingleCut`), the `params`
dictionary should be empty `{}`.

## The `file` Reference Pattern

System entities (buses, lines, hydros, thermals, etc.) and some scenario data
(inflow parameters, load values, graph definition) can be defined in external
CSV or JSONC files. The referencing object uses a `"file"` key:

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

For CSV-based entities, a `default_values` dictionary can supply values for columns
that are missing or contain empty cells. Each CSV row becomes one entity; column names
must match the expected field names exactly.

For JSONC-based data (like `graph.jsonc` or `inflow_scenarios.jsonc`), the `file`
key appears inside the `params` of a `kind`/`params` block:

```jsonc
{
  "kind": "Naive",
  "params": {
    "file": "inflow_scenarios.jsonc",
  },
}
```

!!! note
All file paths are relative to the `data/` directory specified in `main.jsonc`.

## Default Values and Optional Keys

Many engine configuration keys are optional and have sensible defaults:

| Key               | Default                      | Section |
| ----------------- | ---------------------------- | ------- |
| `sampling_scheme` | `DefaultSampling`            | policy  |
| `duality_handler` | `DefaultDuality`             | policy  |
| `forward_pass`    | `DefaultForwardPassStrategy` | policy  |
| `cut_type`        | `SingleCut`                  | policy  |
| `scaling`         | `NoScaling`                  | policy  |
| `logging`         | Default log config           | policy  |
| `solver`          | `HiGHS` with no attributes   | engine  |
| `diagnostics`     | Report off, thresholds high  | engine  |
| `debug`           | All debugging disabled       | engine  |
| `validation`      | No validation                | engine  |
| `modeling`        | `InflowNone`                 | engine  |

Required keys (with no defaults) include: `convergence`, `risk_measure`, and
`parallel_scheme` in the policy section, and `num_simulated_series` and
`parallel_scheme` in the simulation section.

## Minimal Complete Example

Below is a minimal `main.jsonc` that defines a complete study:

```jsonc
{
  "inputs": {
    "path": "data",
    "files": {
      "scenarios": "scenarios.jsonc",
      "system": "system.jsonc",
      "constraints": "constraints.jsonc",
    },
  },
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      "policy": {
        "convergence": {
          "min_iterations": 10,
          "max_iterations": 100,
          "stopping_criteria": {
            "kind": "IterationLimit",
            "params": {
              "num_iterations": 100,
            },
          },
        },
        "risk_measure": {
          "kind": "Expectation",
          "params": {},
        },
        "parallel_scheme": {
          "kind": "Serial",
          "params": {},
        },
      },
      "simulation": {
        "num_simulated_series": 100,
        "parallel_scheme": {
          "kind": "Serial",
          "params": {},
        },
      },
    },
  },
}
```

This example uses all defaults for optional keys: HiGHS solver, single cuts,
no scaling, no diagnostics, no debug output, no validation, and default
sampling/duality/forward-pass strategies.
