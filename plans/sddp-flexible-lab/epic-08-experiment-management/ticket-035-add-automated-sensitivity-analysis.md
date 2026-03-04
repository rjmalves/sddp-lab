# ticket-035 Add Automated Sensitivity Analysis

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify sensitivity parameters are SDDP-meaningful)

## Context

### Background

With the experiment runner from ticket-034 in place, users can compare named configurations. However, constructing every variant by hand is tedious for systematic parameter sweeps. Sensitivity analysis automates this: the user specifies one or more parameters and a range of values, and the framework generates all configurations, runs them through the experiment pipeline, and collects the results.

This ticket builds a sensitivity analysis layer on top of the experiment runner. It supports one-at-a-time (OAT) sweeps (vary one parameter while holding others at their base value) and optionally full-factorial sweeps (all combinations of parameter values). OAT is the default because full-factorial explodes combinatorially and is rarely needed for initial exploration.

### Relation to Epic

This is the second ticket in Epic 08. It extends the experiment runner (ticket-034) with automated configuration generation. The result aggregation ticket (ticket-036) will consume the structured output from sensitivity runs.

### Current State

After ticket-034:

- `src/Experiments/Experiments.jl` module exists with `ExperimentConfig`, `run_experiment`, `read_experiment_config`
- `src/Experiments/merge.jl` provides `deep_merge` for Dict{String,Any}
- `src/Experiments/runner.jl` orchestrates sequential config execution
- `src/Experiments/types.jl` defines `ExperimentResult`
- The experiment runner saves results in `<output_dir>/<config_name>/`
- `experiment_summary.csv` captures per-config metadata

## Specification

### Requirements

1. Create `src/Experiments/sensitivity.jl` with a `SensitivityConfig` struct and `run_sensitivity` function
2. Define a `sensitivity.jsonc` format that specifies:
   - `base_study`: path to the base study directory
   - `output_dir`: where results go
   - `mode`: `"oat"` (one-at-a-time, default) or `"factorial"` (full factorial)
   - `parameters`: a list of parameter sweep definitions, each with:
     - `path`: JSON path to the parameter within `engine.params` (e.g., `"policy.risk_measure.params.alpha"`)
     - `values`: list of values to sweep (e.g., `[0.1, 0.2, 0.5, 0.9]`)
     - `label`: human-readable name for the parameter (e.g., `"CVaR alpha"`)
   - `base_overrides`: optional dict of engine overrides applied to ALL generated configs (e.g., to set a common iteration limit)
3. For OAT mode: for each parameter, generate N configs (one per value), keeping all other parameters at their base study values. Total configs = sum of all parameter value counts.
4. For factorial mode: generate all combinations of parameter values. Total configs = product of all parameter value counts.
5. Config names are auto-generated: `<label_snake_case>_<value>` for OAT; `<label1>_<v1>__<label2>_<v2>` for factorial.
6. `run_sensitivity` internally constructs an `ExperimentConfig` from the generated configs and delegates to `run_experiment` (or its internal runner loop).
7. Return a `SensitivityResult` containing all `ExperimentResult` entries plus the parameter metadata (which parameter was varied, what values).

### Sensitivity JSONC Format

```jsonc
{
  "base_study": "../example/1dtoy",
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
      "path": "policy.risk_measure",
      "values": [
        { "kind": "Expectation", "params": {} },
        { "kind": "CVaR", "params": { "alpha": 0.2, "lambda": 0.9 } },
        { "kind": "AVaR", "params": { "alpha": 0.5 } },
      ],
      "label": "risk_measure",
    },
    {
      "path": "simulation.num_simulated_series",
      "values": [50, 100, 500],
      "label": "num_simulations",
    },
  ],
}
```

### Inputs/Props

- `config_path::String` -- path to the `sensitivity.jsonc` file
- Parameter paths use dot-notation into the engine params dict (e.g., `"policy.convergence.max_iterations"`)
- Values can be scalars (Int, Float64, String) or dicts (for structured objects like risk measures)

### Outputs/Behavior

- `SensitivityResult` struct:
  - `mode::String` ("oat" or "factorial")
  - `parameters::Vector{SensitivityParameter}` (label, path, values)
  - `results::Vector{ExperimentResult}` (one per generated config)
  - `summary_path::String` (path to the summary CSV)
- In OAT mode with the example above: 3 (risk_measure) + 3 (num_simulations) = 6 configs
- In factorial mode: 3 x 3 = 9 configs
- A `sensitivity_summary.csv` is written with columns: config_name, parameter_label, parameter_value, success, train_time_s, simulate_time_s, error
- Directory structure: `<output_dir>/<config_name>/` for each generated config

### Error Handling

- Invalid parameter path (does not resolve to a key in the base engine config): error at parse time with a clear message indicating the valid path structure
- Empty values list for a parameter: error at parse time
- Factorial mode with more than 100 combinations: warn the user but proceed (do NOT silently truncate)
- Individual config failures: handled by the experiment runner (ticket-034); recorded in summary

## Acceptance Criteria

- [ ] C1: Given a `sensitivity.jsonc` with 2 parameters (3 values each) in OAT mode, when `run_sensitivity` is called, then exactly 6 configurations are generated and executed
- [ ] C2: Given a `sensitivity.jsonc` with 2 parameters (2 values each) in factorial mode, when `run_sensitivity` is called, then exactly 4 configurations are generated and executed
- [ ] C3: Given a parameter path `"policy.risk_measure"` with a dict value `{"kind": "CVaR", "params": {"alpha": 0.2, "lambda": 0.9}}`, when the config is generated, then the base study's risk measure is replaced with the specified CVaR configuration
- [ ] C4: Given a parameter path `"simulation.num_simulated_series"` with a scalar value `50`, when the config is generated, then only that single field is overridden in the deep-merged config
- [ ] C5: Given `base_overrides` that set `max_iterations: 50`, when configs are generated, then every generated config has `max_iterations: 50` regardless of the base study value
- [ ] C6: `sensitivity_summary.csv` exists after a successful run and contains the parameter_label and parameter_value columns for traceability

## Implementation Guide

### Suggested Approach

1. Create `src/Experiments/sensitivity.jl` with:
   - `SensitivityParameter` struct: `label::String`, `path::String`, `values::Vector{Any}`
   - `SensitivityConfig` struct: `base_study::String`, `output_dir::String`, `mode::String`, `base_overrides::Dict{String,Any}`, `parameters::Vector{SensitivityParameter}`
   - `SensitivityResult` struct: `mode`, `parameters`, `results`, `summary_path`

2. Implement `_resolve_path(dict, dotpath)` to navigate a nested Dict via dot-separated keys (e.g., `"policy.risk_measure.params.alpha"` resolves through `dict["policy"]["risk_measure"]["params"]["alpha"]`). Use this for validation (checking the path exists in the base config).

3. Implement `_set_path!(dict, dotpath, value)` to set a value at a dot-separated path in a nested Dict, creating intermediate dicts if needed.

4. Implement `_generate_oat_configs(base_overrides, parameters)` that returns a `Vector{Tuple{String, Dict{String,Any}}}` of (config_name, overrides):

   ```julia
   for param in parameters
       for value in param.values
           overrides = deepcopy(base_overrides)
           _set_path!(overrides, param.path, value)
           name = _sanitize_config_name("$(param.label)_$(value)")
           push!(configs, (name, overrides))
       end
   end
   ```

5. Implement `_generate_factorial_configs(base_overrides, parameters)` using `Iterators.product` to generate all combinations.

6. `run_sensitivity` constructs the configs, builds an `ExperimentConfig`, calls the runner loop, then writes `sensitivity_summary.csv`.

7. Add includes and exports to `src/Experiments/Experiments.jl`.

### Key Files to Create/Modify

| File                                   | Action | Description                                                                                            |
| -------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------ |
| `src/Experiments/sensitivity.jl`       | Create | `SensitivityConfig`, `SensitivityParameter`, `SensitivityResult`, `run_sensitivity`, config generators |
| `src/Experiments/Experiments.jl`       | Modify | Add `include("sensitivity.jl")` and exports                                                            |
| `src/SDDPlab.jl`                       | Modify | Add sensitivity exports if needed                                                                      |
| `test/Experiments/test-sensitivity.jl` | Create | Tests for sensitivity analysis                                                                         |

### Patterns to Follow

- Reuse the experiment runner's `_run_single_config` from ticket-034 for actual execution
- Reuse `deep_merge` from `src/Experiments/merge.jl` for applying overrides
- Use `CompositeException` for validation errors in config parsing
- Use `CSV.write` for the summary CSV
- Auto-generated config names: `_sanitize_config_name(s)` should replace spaces, dots, and special chars with underscores, then truncate to 60 chars

### Pitfalls to Avoid

- **Parameter path validation**: The dot-path must be validated against the base study's engine config to ensure it resolves to an actual key. Do NOT silently ignore invalid paths.
- **Value type matching**: When a parameter path points to an Integer field and the value is a Float64, the JSON parser will give Float64. Let the existing Study constructor handle type validation -- do not add redundant type checking here.
- **Dict values in parameter sweeps**: When sweeping structured objects (like risk measures), the entire sub-dict at the path should be replaced, not merged. Only `base_overrides` uses deep merge.
- **Config name collisions**: In factorial mode, if two different parameter combinations produce the same sanitized name, append a numeric suffix.
- **Working directory**: Same `pwd()` management concerns as ticket-034 -- use `try-finally` blocks.

## Testing Requirements

### Unit Tests

- `_resolve_path` correctly navigates nested dicts; returns `nothing` for invalid paths
- `_set_path!` creates intermediate dicts and sets leaf values
- `_generate_oat_configs` produces correct count and names for given parameters
- `_generate_factorial_configs` produces correct count (product) for given parameters
- `_sanitize_config_name` handles special characters and length limits

### Integration Tests

- Run OAT sensitivity on `example/1dtoy` with 1 parameter (2 values), `max_iterations: 3` -- verify 2 output directories and `sensitivity_summary.csv`
- Run factorial sensitivity on `example/1dtoy` with 2 parameters (2 values each), `max_iterations: 3` -- verify 4 output directories
- **Use `TEST_FILTER="test-sensitivity"` and 180000ms Bash timeout**

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-034 (experiment runner must exist)
- **Blocks**: ticket-036

## Effort Estimate

**Points**: 3
**Confidence**: High
