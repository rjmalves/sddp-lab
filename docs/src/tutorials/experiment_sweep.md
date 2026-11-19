# Experiment Runner and Sensitivity Analysis

## Overview

This tutorial demonstrates the **experiment runner** and **sensitivity analysis** features in SDDPlab.jl. These tools automate the execution of multiple study configurations from a single base study, enabling systematic comparison of algorithmic settings, risk measures, and other parameters.

- **Experiment runner**: Define named configurations with engine-parameter overrides and run them all in batch
- **Sensitivity analysis**: Sweep one or more parameters over a range of values (one-at-a-time or full factorial) and collect summary statistics

Both features build on the same pipeline (`read_study -> build -> train -> simulate -> save`) but automate the parameter variation and result aggregation.

## Study Description

This example uses the `1dtoy` example as the base study (1 bus, 1 hydro, 2 thermals, 4 stages). It defines:

1. An **experiment** with 3 configurations varying the risk measure:
   - `expectation`: Risk-neutral (Expectation)
   - `cvar_02`: CVaR with alpha=0.2, lambda=0.5
   - `cvar_05`: CVaR with alpha=0.5, lambda=0.5

2. A **sensitivity analysis** sweeping the maximum iteration count:
   - Values: 32, 64, 128

## Configuration Walkthrough

### Experiment Configuration (`experiment.jsonc`)

```json
{
    "base_study": "../1dtoy",
    "output_dir": "output_experiment",
    "overwrite": true,
    "configurations": {
        "expectation": {
            "policy": {
                "risk_measure": {
                    "kind": "Expectation",
                    "params": {}
                },
                "convergence": {
                    "max_iterations": 32,
                    "stopping_criteria": {
                        "kind": "IterationLimit",
                        "params": { "num_iterations": 32 }
                    }
                }
            }
        },
        "cvar_02": { ... },
        "cvar_05": { ... }
    }
}
```

Key fields:

- `base_study`: Relative path to the directory containing `main.jsonc`
- `output_dir`: Where to write per-configuration results (relative to the experiment file)
- `overwrite`: Set `true` to allow re-running without clearing the output directory
- `configurations`: A dictionary of named configs, each containing engine-parameter overrides that are deep-merged with the base study's engine params

Configuration names must match the pattern `^[a-zA-Z0-9_-]+$`.

### Sensitivity Configuration (`sensitivity.jsonc`)

```json
{
  "base_study": "../1dtoy",
  "output_dir": "output_sensitivity",
  "mode": "oat",
  "overwrite": true,
  "parameters": [
    {
      "label": "max_iterations",
      "path": "policy.convergence.max_iterations",
      "values": [32, 64, 128]
    }
  ]
}
```

Key fields:

- `mode`: `"oat"` (one-at-a-time, default) or `"factorial"` (full factorial cross-product)
- `parameters[].path`: Dot-separated path into the engine params dictionary
- `parameters[].values`: Array of values to sweep over
- `parameters[].label`: Human-readable name used in config names and the summary CSV

In OAT mode with 1 parameter and 3 values, this generates 3 configurations. In factorial mode with 2 parameters of 3 values each, it would generate 9 configurations.

## Running the Example

### Experiment

```julia
using SDDPlab

results = SDDPlab.run_experiment("example/experiment_sweep/experiment.jsonc")
for r in results
    status = r.success ? "ok" : r.error_message
    println("$(r.config_name): $status (train=$(r.train_elapsed_seconds)s)")
end
```

### Sensitivity Analysis

```julia
using SDDPlab

result = SDDPlab.run_sensitivity("example/experiment_sweep/sensitivity.jsonc")
println("Mode: ", result.mode)
println("Summary: ", result.summary_path)
```

## Expected Output

### Experiment Output

The experiment runner creates:

```
output_experiment/
    expectation/       # Full simulation results for risk-neutral policy
    cvar_02/           # Full simulation results for CVaR alpha=0.2
    cvar_05/           # Full simulation results for CVaR alpha=0.5
    experiment_summary.csv
```

The summary CSV contains columns: `config_name`, `success`, `train_time_s`, `simulate_time_s`, `error`.

### Sensitivity Output

The sensitivity runner creates:

```
output_sensitivity/
    max_iterations_32/
    max_iterations_64/
    max_iterations_128/
    sensitivity_summary.csv
```

The sensitivity summary CSV adds columns for `parameter_label` and `parameter_value`.

## Variations

- Add a second parameter to the sensitivity config (e.g., `simulation.num_simulated_series` with values [10, 50, 100]) and switch to `"factorial"` mode
- Use structured values in the sensitivity sweep (e.g., sweep over risk measures by providing dict values instead of scalars)
- Add `base_overrides` to the sensitivity config to set a common fast convergence criterion across all sweep configurations
- Reference a more complex base study (e.g., `../4ree`) for a realistic multi-bus sensitivity analysis
