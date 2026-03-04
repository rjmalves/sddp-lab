# SDDPlab.jl

SDDPlab.jl is a Julia laboratory for developing and experimenting with
[Stochastic Dual Dynamic Programming (SDDP)](https://sddp.dev/stable/) applied
to hydrothermal optimal power dispatch problems.

The package provides a complete, configuration-driven pipeline for building,
training, and simulating multi-stage stochastic optimization models of power
systems. It is built on top of [SDDP.jl](https://sddp.dev/stable/) and
[JuMP.jl](https://jump.dev/), and is designed to make it easy to experiment
with different algorithmic variants (risk measures, stopping criteria,
parallelism strategies, etc.) without changing any Julia code.

## Key Features

- **Configuration-driven**: All model settings (system topology, scenario
  generation, solver, risk measure, etc.) are defined in `main.jsonc` and
  loaded at runtime.
- **Full pipeline**: `read_study → build → train → simulate → save` with a
  single consistent interface.
- **Rich system model**: Hydro cascades, thermals, non-controllable renewables,
  energy contracts, pumping stations, and transmission lines.
- **Flexible stochastic processes**: Naive (copula-based), AR(p), and VAR(p)
  inflow models with optional Markov chain regime switching.
- **Experiment management**: Run multiple configurations, sensitivity sweeps,
  and result comparisons with a few lines of code.
- **Reproducibility tools**: Environment snapshots, config hashing, and
  metadata tracking for every run.

## Quick Example

```julia
using SDDPlab

# 1. Read and validate the study configuration
study = read_study("/path/to/my_study")

# 2. Build the SDDP model
model = build(study)

# 3. Train the policy
artifact_policy = train(study, model)

# 4. Simulate on the trained policy
artifact_sim = simulate(study, model)

# 5. Save results to CSV
save_simulation(study, artifact_sim, "/path/to/output", CSVFormat())
save_policy(study, artifact_policy, "/path/to/output", CSVFormat())
```

## Found a Bug?

Please report unexpected behavior by
[opening an issue](https://github.com/rjmalves/sddp-lab/issues).

## Documentation Contents

```@contents
Pages = [
    "man/getting_started.md",
    "api/pipeline.md",
    "api/system.md",
    "api/scenarios.md",
    "api/stochastic.md",
    "api/engine.md",
    "api/experiments.md",
    "api/observability.md",
    "api/variables.md",
]
Depth = 2
```
