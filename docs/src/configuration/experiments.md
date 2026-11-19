# Experiment Orchestration

SDDPlab.jl provides two experiment orchestration formats for running multiple
configurations automatically: `experiment.jsonc` for named configurations and
`sensitivity.jsonc` for parameter sweeps. These files live alongside (not
inside) a study directory.

## Experiment Configuration (`experiment.jsonc`)

An experiment file defines a base study and a set of named configurations,
each with engine parameter overrides. SDDPlab runs the full
`build -> train -> simulate -> save` pipeline for each configuration.

### Top-Level Structure

```jsonc
{
  "base_study": "../my_study",
  "output_dir": "results",
  "overwrite": false,
  "configurations": {
    "risk_neutral": {
      "policy": {
        "risk_measure": {
          "kind": "Expectation",
          "params": {},
        },
      },
    },
    "risk_averse": {
      "policy": {
        "risk_measure": {
          "kind": "CVaR",
          "params": { "alpha": 0.2, "lambda": 0.9 },
        },
      },
    },
  },
}
```

### Top-Level Keys

| Key              | Type   | Required | Default     | Description                                              |
| ---------------- | ------ | -------- | ----------- | -------------------------------------------------------- |
| `base_study`     | String | Yes      | --          | Path to the base study directory (contains `main.jsonc`) |
| `output_dir`     | String | No       | `"results"` | Output directory for results                             |
| `overwrite`      | Bool   | No       | `false`     | Allow writing into a non-empty output directory          |
| `configurations` | Object | Yes      | --          | Named configurations with engine param overrides         |

### Path Resolution

- `base_study`: Resolved relative to the directory containing the `experiment.jsonc` file. Must be a directory containing `main.jsonc`.
- `output_dir`: Resolved relative to the directory containing the `experiment.jsonc` file.

### Configuration Names

Configuration names must match `^[a-zA-Z0-9_-]+$` (alphanumeric characters,
underscores, and hyphens only). Each name becomes a subdirectory under
`output_dir`.

### Configuration Overrides

Each configuration value is a dictionary of engine parameter overrides that are
deep-merged into the base study's engine `params`. The override structure
mirrors the engine params hierarchy. For example, to override only the risk
measure:

```jsonc
{
  "policy": {
    "risk_measure": {
      "kind": "Expectation",
      "params": {},
    },
  },
}
```

### Example

```jsonc
{
  "base_study": "../1dtoy",
  "output_dir": "experiment_results",
  "overwrite": false,
  "configurations": {
    "baseline": {},
    "more_iterations": {
      "policy": {
        "convergence": {
          "max_iterations": 500,
          "stopping_criteria": {
            "kind": "IterationLimit",
            "params": { "num_iterations": 500 },
          },
        },
      },
    },
    "multicut": {
      "policy": {
        "cut_type": {
          "kind": "MultiCut",
          "params": {},
        },
      },
    },
  },
}
```

## Sensitivity Configuration (`sensitivity.jsonc`)

A sensitivity file defines a parameter sweep over one or more engine parameters.
SDDPlab automatically generates all configurations and runs them.

### Top-Level Structure

```jsonc
{
  "base_study": "../my_study",
  "output_dir": "sensitivity_results",
  "mode": "oat",
  "overwrite": false,
  "base_overrides": {},
  "parameters": [
    {
      "label": "risk_alpha",
      "path": "policy.risk_measure.params.alpha",
      "values": [0.1, 0.3, 0.5, 0.7, 0.9],
    },
  ],
}
```

### Top-Level Keys

| Key              | Type   | Required | Default                 | Valid Values             | Description                             |
| ---------------- | ------ | -------- | ----------------------- | ------------------------ | --------------------------------------- |
| `base_study`     | String | Yes      | --                      | --                       | Path to the base study directory        |
| `output_dir`     | String | No       | `"sensitivity_results"` | --                       | Output directory for results            |
| `mode`           | String | No       | `"oat"`                 | `"oat"` or `"factorial"` | Sweep mode                              |
| `overwrite`      | Bool   | No       | `false`                 | --                       | Allow writing into non-empty directory  |
| `base_overrides` | Object | No       | `{}`                    | --                       | Overrides applied to all configurations |
| `parameters`     | Array  | Yes      | --                      | Non-empty                | Parameter definitions to sweep          |

### Path Resolution

Same as experiment configuration: paths are resolved relative to the
`sensitivity.jsonc` file's directory.

### Sweep Modes

- **`oat`** (One-At-a-Time): For each parameter, sweep through its values
  independently while keeping all others at their base values. Generates
  `sum(length(p.values) for p in parameters)` configurations.

- **`factorial`**: Full factorial design -- all combinations of all parameter
  values. Generates `product(length(p.values) for p in parameters)`
  configurations.

!!! warning
Factorial mode can generate a very large number of configurations. A warning
is logged when more than 100 combinations are generated.

### Parameter Definitions

Each entry in the `parameters` array:

| Key      | Type   | Required | Constraints | Description                            |
| -------- | ------ | -------- | ----------- | -------------------------------------- |
| `label`  | String | Yes      | Non-empty   | Human-readable name for this parameter |
| `path`   | String | Yes      | Non-empty   | Dot-separated path into engine params  |
| `values` | Array  | Yes      | Non-empty   | Values to sweep over                   |

The `path` uses dot notation to navigate the engine params hierarchy. For
example:

- `"policy.risk_measure"` -- replaces the entire risk measure
- `"simulation.num_simulated_series"` -- replaces a scalar value
- `"policy.convergence.max_iterations"` -- replaces a nested scalar

Values can be scalars (integers, floats, strings) or structured objects (dicts)
for replacing complex config blocks like risk measures.

### Base Overrides

The `base_overrides` dictionary is applied to every generated configuration
before the per-parameter sweep value is applied. This is useful for setting
common overrides (e.g., reducing iterations for faster sweeps):

```jsonc
{
  "base_overrides": {
    "policy": {
      "convergence": {
        "max_iterations": 50,
        "stopping_criteria": {
          "kind": "IterationLimit",
          "params": { "num_iterations": 50 },
        },
      },
    },
  },
}
```

### Configuration Naming

Configuration names are auto-generated from the parameter label and value,
sanitized to `[a-z0-9_-]` with a 60-character limit. Duplicate names are
resolved by appending a numeric suffix.

### Output

After all configurations are run, a `sensitivity_summary.csv` is written to
the output directory with columns:

| Column            | Description                            |
| ----------------- | -------------------------------------- |
| `config_name`     | Generated configuration name           |
| `parameter_label` | Label of the parameter being swept     |
| `parameter_value` | Value used for this configuration      |
| `success`         | Whether the run completed successfully |
| `train_time_s`    | Training wall-clock time (seconds)     |
| `simulate_time_s` | Simulation wall-clock time (seconds)   |
| `error`           | Error message (empty if successful)    |

### Example: One-At-a-Time Sweep

```jsonc
{
  "base_study": "../1dtoy",
  "output_dir": "sensitivity_results",
  "mode": "oat",
  "base_overrides": {
    "policy": {
      "convergence": {
        "max_iterations": 50,
        "stopping_criteria": {
          "kind": "IterationLimit",
          "params": { "num_iterations": 50 },
        },
      },
    },
  },
  "parameters": [
    {
      "label": "risk_measure",
      "path": "policy.risk_measure",
      "values": [
        { "kind": "Expectation", "params": {} },
        { "kind": "CVaR", "params": { "alpha": 0.2, "lambda": 0.5 } },
        { "kind": "CVaR", "params": { "alpha": 0.2, "lambda": 0.9 } },
      ],
    },
    {
      "label": "num_series",
      "path": "simulation.num_simulated_series",
      "values": [50, 100, 200],
    },
  ],
}
```

This generates 6 configurations (3 risk measures + 3 series counts).

### Example: Factorial Sweep

```jsonc
{
  "base_study": "../1dtoy",
  "output_dir": "factorial_results",
  "mode": "factorial",
  "parameters": [
    {
      "label": "alpha",
      "path": "policy.risk_measure.params.alpha",
      "values": [0.1, 0.5],
    },
    {
      "label": "lambda",
      "path": "policy.risk_measure.params.lambda",
      "values": [0.5, 0.9],
    },
  ],
}
```

This generates 4 configurations (2 alpha values x 2 lambda values).
