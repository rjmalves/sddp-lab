# Getting Started

This section explains how to install SDDPlab.jl and run your first study.

## Installation

SDDPlab.jl is not registered in the Julia General registry. Install it directly
from GitHub:

```bash
export JULIA_PKG_USE_CLI_GIT=true
julia --project -e 'using Pkg; Pkg.add(url="https://github.com/rjmalves/sddp-lab.git")'
```

On Windows (PowerShell):

```powershell
$env:JULIA_PKG_USE_CLI_GIT = "true"
julia --project -e 'using Pkg; Pkg.add(url="https://github.com/rjmalves/sddp-lab.git")'
```

Julia 1.10 or higher is required.

## The Core Pipeline

SDDPlab.jl uses a five-step pipeline to train and simulate an SDDP policy:

```julia
using SDDPlab

# Step 1 — read and validate the study from a directory containing main.jsonc
study = read_study("/path/to/my_study")

# Step 2 — build the SDDP.PolicyGraph model
model = build(study)

# Step 3 — train the policy (cut-generation loop)
artifact_policy = train(study, model)

# Step 4 — simulate on the trained policy
artifact_sim = simulate(study, model)

# Step 5 — save results (CSV or Parquet)
save_policy(study, artifact_policy, "/path/to/output", CSVFormat())
save_simulation(study, artifact_sim, "/path/to/output", CSVFormat())
```

The solver is configured in `main.jsonc` — there is no need to pass an
optimizer as a Julia argument.

## Study Directory Structure

Every SDDPlab study is a directory containing a `main.jsonc` entry-point file.
A minimal study looks like this:

```
my_study/
├── main.jsonc            # entry point: wires all sub-configs
├── system.jsonc          # power system topology and components
├── buses.csv             # bus definitions
├── thermals.csv          # thermal plant definitions
├── hydros.csv            # hydro plant definitions
├── scenarios.jsonc       # graph topology and inflow scenario config
└── stochastic_process.jsonc  # AR/VAR/Naive inflow model parameters
```

### The `main.jsonc` File

The `main.jsonc` file is the entry point. It links all input files and
configures the engine:

```jsonc
{
  "inputs": {
    "files": {
      "system": "system.jsonc",
      "scenarios": "scenarios.jsonc",
    },
  },
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      "solver": {
        "name": "HiGHS",
        "attributes": {},
      },
      "policy": {
        "convergence": {
          "min_iterations": 10,
          "max_iterations": 200,
          "stopping_criteria": [
            {
              "kind": "IterationLimit",
              "params": { "num_iterations": 200 },
            },
          ],
        },
        "risk_measure": { "kind": "Expectation", "params": {} },
        "parallel_scheme": { "kind": "Serial", "params": {} },
        "cut_type": { "kind": "SingleCut", "params": {} },
        "scaling": { "kind": "NoScaling", "params": {} },
      },
      "simulation": {
        "num_simulated_series": 200,
      },
    },
  },
}
```

Key points:

- The `"solver"` is specified by name (`"HiGHS"`, `"GLPK"`, `"Gurobi"`, etc.).
  The solver package must be installed and loaded.
- All algorithm variants (`risk_measure`, `stopping_criteria`, etc.) use the
  `{"kind": "TypeName", "params": {...}}` pattern.
- The solver and algorithm are decoupled from the system model.

## Running an Experiment

To compare multiple algorithm configurations, use [`run_experiment`](@ref):

```julia
using SDDPlab

results = run_experiment("/path/to/experiment.jsonc")
for r in results
    println(r.config_name, ": ", r.success ? "ok" : r.error_message)
end
```

The `experiment.jsonc` file specifies a base study and a set of engine-parameter
overrides for each configuration:

```jsonc
{
  "base_study": "../my_study",
  "output_dir": "results",
  "configurations": {
    "expectation": {},
    "cvar_5pct": {
      "policy": {
        "risk_measure": {
          "kind": "CVaR",
          "params": { "alpha": 0.05, "lambda": 0.5 },
        },
      },
    },
  },
}
```

## Output Files

After [`save_simulation`](@ref) completes, the output directory contains one
CSV (or Parquet) file per monitored variable, e.g.:

| File                     | Contents                                       |
| ------------------------ | ---------------------------------------------- |
| `operation_system.csv`   | All variables, long format                     |
| `hydro_generation.csv`   | Hydro generation per plant and scenario        |
| `thermal_generation.csv` | Thermal dispatch per plant and scenario        |
| `stored_volume.csv`      | Reservoir storage trajectories                 |
| `cuts.csv`               | SDDP Benders cut coefficients                  |
| `convergence.csv`        | Lower bound and simulation value per iteration |

## Next Steps

- See the [API Reference — Core Pipeline](../api/pipeline.md) for detailed
  documentation of each pipeline function.
- See the [Engine Configuration](../api/engine.md) page for all
  available stopping criteria, risk measures, and solver options.
- See the [Experiments](../api/experiments.md) page for experiment management and
  sensitivity analysis.
