# ticket-034 Implement Multi-Configuration Experiment Runner

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify experiment design covers meaningful SDDP parameter variations)

## Context

### Background

SDDPlab now supports a rich set of algorithm configurations (risk measures, stopping criteria, sampling schemes, duality handlers, forward passes, cut types, scaling modes, inflow non-negativity methods, Markov chains, out-of-sample validation) and system elements (thermals, hydros, non-controllable generation, energy contracts, pumping stations, load blocks). Users need the ability to systematically compare multiple algorithm configurations on the same problem instance without manually editing `main.jsonc` and re-running the pipeline for each variant.

This ticket creates a new `Experiments` module that provides a thin orchestration layer on top of the existing `read_study -> build -> train -> simulate -> save_*` pipeline. It introduces an `experiment.jsonc` configuration format and a `run_experiment` function that executes the full pipeline for each listed configuration, saving results in a structured directory layout.

### Relation to Epic

This is the foundation ticket for Epic 08 (Experiment Management). It establishes the `Experiments` module, the experiment configuration format, and the sequential multi-config runner. All subsequent tickets in this epic (sensitivity analysis, result aggregation, reproducibility) build on this infrastructure.

### Current State

- The public API in `src/study.jl` provides: `read_study(path)`, `build(study)`, `train(study, model)`, `simulate(study, model)`, `save_simulation(...)`, `validate(study, model)`, `save_validation(...)`
- A study is read from a directory containing `main.jsonc` which defines `inputs` (path + files) and `engine` (kind + params)
- The engine config is a single `SDDPEngine` with fixed policy/simulation/diagnostics/solver/modeling/validation sections
- There is no mechanism to run multiple engine configurations against the same input data
- `src/SDDPlab.jl` includes modules in order: Lab, Utils, StochasticProcess, System, Scenarios, Inputs, Engines, then `study.jl`

## Specification

### Requirements

1. Create a new module `src/Experiments/Experiments.jl` that depends on the existing SDDPlab public API
2. Define an `ExperimentConfig` struct that holds: a base study path, a list of named configuration overrides (each overriding parts of the engine config), and an output directory
3. Define an `experiment.jsonc` format that specifies the base study and a list of named configurations
4. Implement `run_experiment(config_path::String)` that:
   a. Reads the experiment config from `experiment.jsonc`
   b. For each named configuration: reads the base study, applies engine overrides via deep-merge, builds, trains, simulates, and saves results to `<output_dir>/<config_name>/`
   c. Returns an `ExperimentResult` containing per-config metadata (config name, output path, training time, simulation time, any errors)
5. Implement `read_experiment_config(path::String)` to parse and validate the experiment JSONC
6. Engine overrides use the same JSONC structure as `engine.params` but only the keys being overridden need to be present (deep merge with the base config)

### Experiment JSONC Format

```jsonc
{
  "base_study": "../example/1dtoy",
  "output_dir": "results",
  "configurations": {
    "expectation_100iter": {
      "policy": {
        "risk_measure": {
          "kind": "Expectation",
          "params": {},
        },
        "convergence": {
          "max_iterations": 100,
          "stopping_criteria": {
            "kind": "IterationLimit",
            "params": { "num_iterations": 100 },
          },
        },
      },
    },
    "cvar_alpha02_100iter": {
      "policy": {
        "risk_measure": {
          "kind": "CVaR",
          "params": { "alpha": 0.2, "lambda": 0.9 },
        },
        "convergence": {
          "max_iterations": 100,
          "stopping_criteria": {
            "kind": "IterationLimit",
            "params": { "num_iterations": 100 },
          },
        },
      },
    },
  },
}
```

### Inputs/Props

- `config_path::String` -- path to the `experiment.jsonc` file
- The base study path is relative to the experiment.jsonc file's directory
- Each configuration name must be a valid directory name (alphanumeric + underscore + hyphen)

### Outputs/Behavior

- `ExperimentResult` struct containing:
  - `config_name::String`
  - `output_path::String`
  - `train_elapsed_seconds::Float64`
  - `simulate_elapsed_seconds::Float64`
  - `success::Bool`
  - `error_message::Union{String,Nothing}`
- Each configuration's results are saved in `<output_dir>/<config_name>/` using the existing `save_simulation` and `save_policy` functions
- Configurations run sequentially (parallel execution is NOT in scope for this ticket)
- If one configuration fails, the runner logs the error and continues to the next configuration
- A summary `experiment_summary.csv` is written to `<output_dir>/` with columns: config_name, success, train_time_s, simulate_time_s, error

### Error Handling

- Invalid experiment.jsonc: accumulate errors via `CompositeException`, return immediately with error details
- Invalid config name (contains path separators or special chars): error at parse time
- Base study not found: error at parse time
- Individual config failure (build/train/simulate): catch the exception, record in `ExperimentResult`, continue to next config
- Output directory creation: create if not exists, error if exists and is not empty (unless `overwrite: true` in config)

## Acceptance Criteria

- [ ] C1: Given a valid `experiment.jsonc` with 2 configurations, when `run_experiment(path)` is called, then both configurations are executed and results are saved in separate subdirectories under `<output_dir>/`
- [ ] C2: Given an `experiment.jsonc` where the second configuration has an invalid engine parameter, when `run_experiment(path)` is called, then the first configuration succeeds, the second fails gracefully, and `experiment_summary.csv` records both outcomes
- [ ] C3: Given a configuration that overrides only `policy.risk_measure`, when the deep merge is applied, then all other engine parameters (simulation, solver, diagnostics, etc.) are inherited from the base study unchanged
- [ ] C4: Given a configuration name containing a path separator (`/`), when `read_experiment_config` is called, then a validation error is returned
- [ ] C5: Given an experiment.jsonc, when `run_experiment` completes, then `experiment_summary.csv` exists in the output directory with correct columns and one row per configuration
- [ ] C6: `ExperimentConfig`, `ExperimentResult`, `run_experiment`, and `read_experiment_config` are exported from the `SDDPlab` module

## Implementation Guide

### Suggested Approach

1. Create the module directory `src/Experiments/` with files:
   - `Experiments.jl` -- module definition, includes, exports
   - `types.jl` -- `ExperimentConfig`, `ConfigOverride`, `ExperimentResult` structs
   - `config.jl` -- `read_experiment_config` parsing and validation
   - `runner.jl` -- `run_experiment` orchestration logic
   - `merge.jl` -- deep-merge utility for Dict{String,Any}

2. The deep-merge function should recursively merge dicts: if both the base and override have a Dict value for the same key, recurse; otherwise the override value wins. This operates on raw `Dict{String,Any}` BEFORE the `Study` constructor is called.

3. The runner loop for each config:

   ```julia
   function _run_single_config(base_study_path, config_name, overrides, output_dir)
       e = CompositeException()
       # Read base main.jsonc as raw dict
       original_pwd = pwd()
       cd(base_study_path)
       base_dict = read_jsonc("main.jsonc", e)
       cd(original_pwd)

       # Deep-merge engine overrides
       merged = deep_merge(base_dict["engine"]["params"], overrides)
       base_dict["engine"]["params"] = merged

       # Build Study from merged dict (re-enter the Study(dict, e) constructor)
       cd(base_study_path)
       study = Study(base_dict, e)
       cd(original_pwd)

       # Execute pipeline
       model = build(study)
       t_train = @elapsed artifact_policy = train(study, model)
       t_sim = @elapsed artifact_sim = simulate(study, model)

       # Save results
       config_output = joinpath(output_dir, config_name)
       mkpath(config_output)
       save_simulation(study, artifact_sim, config_output, CSVFormat())
       save_policy(study, artifact_policy, config_output, CSVFormat())

       return ExperimentResult(config_name, config_output, t_train, t_sim, true, nothing)
   end
   ```

4. Include the module in `src/SDDPlab.jl` after `study.jl` and export the public functions.

5. Write tests in `test/Experiments/test-experiment-runner.jl` using the `example/1dtoy` case with 2 small configurations (low iteration count for fast tests).

### Key Files to Create/Modify

| File                                         | Action | Description                                                               |
| -------------------------------------------- | ------ | ------------------------------------------------------------------------- |
| `src/Experiments/Experiments.jl`             | Create | Module definition with includes and exports                               |
| `src/Experiments/types.jl`                   | Create | `ExperimentConfig`, `ConfigOverride`, `ExperimentResult` structs          |
| `src/Experiments/config.jl`                  | Create | `read_experiment_config` parser with validation                           |
| `src/Experiments/runner.jl`                  | Create | `run_experiment` and `_run_single_config` functions                       |
| `src/Experiments/merge.jl`                   | Create | `deep_merge` utility for Dict{String,Any}                                 |
| `src/SDDPlab.jl`                             | Modify | Add `include("Experiments/Experiments.jl")` after `study.jl`; add exports |
| `test/Experiments/test-experiment-runner.jl` | Create | Tests for experiment runner                                               |

### Patterns to Follow

- Follow the `CompositeException` error accumulation pattern used in all constructors (see `src/study.jl` lines 13-24, `src/Engines/input.jl` lines 1-17)
- Use `read_jsonc` from `src/Utils/reading-utils.jl` for JSONC parsing
- The `Study(d::Dict{String,Any}, e::CompositeException)` constructor in `src/study.jl` line 13 can be reused directly -- feed it the deep-merged dict
- Follow the 4-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`
- Use `@elapsed` for timing (Julia stdlib)
- Use `CSV.write` for the summary CSV (CSV.jl is already a dependency)

### Pitfalls to Avoid

- **Do NOT modify the core pipeline** (`build`, `train`, `simulate`) -- this module is purely orchestration
- **Working directory management**: `read_study` uses `cd(path)` internally. The experiment runner must carefully manage `pwd()` because the base study reads files relative to its own directory. Wrap each config run in a `try-finally` that restores `pwd()`
- **Dict mutation**: The `Study` constructor mutates its input dict (builds internals in-place). Use `deepcopy(base_dict)` before each config run so configs do not pollute each other
- **Never run `test-main` without a 360000ms Bash timeout**; use `TEST_FILTER="test-experiment"` with 180000ms for integration tests
- Config names must be filesystem-safe: validate with regex `^[a-zA-Z0-9_-]+$`

## Testing Requirements

### Unit Tests

- `deep_merge` correctly merges nested dicts (override wins, base preserved for missing keys, nested recursion works)
- `read_experiment_config` validates required fields (base_study, configurations)
- `read_experiment_config` rejects invalid config names
- `ExperimentConfig` construction with valid data succeeds

### Integration Tests

- Run experiment with 2 configs on `example/1dtoy` with `max_iterations: 5` -- verify both output directories exist and contain simulation CSV files
- Run experiment where one config has an invalid engine kind -- verify the other config still runs and `experiment_summary.csv` reflects the failure
- **Use `TEST_FILTER="test-experiment"` and 180000ms Bash timeout**

### E2E Tests

Not applicable -- integration tests cover the full pipeline.

## Dependencies

- **Blocked By**: ticket-033 (Epic 07 complete -- all pipeline features available)
- **Blocks**: ticket-035, ticket-036, ticket-037

## Effort Estimate

**Points**: 4
**Confidence**: High
