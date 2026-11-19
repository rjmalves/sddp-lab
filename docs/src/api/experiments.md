# Experiments

The experiments module provides tools for running multiple study configurations,
performing sensitivity analyses, and comparing results across runs.

## Experiment Runner

```@docs
run_experiment
read_experiment_config
ExperimentConfig
ExperimentResult
```

## Sensitivity Analysis

```@docs
run_sensitivity
read_sensitivity_config
SensitivityConfig
SensitivityParameter
SensitivityResult
```

## Result Comparison

```@docs
aggregate_experiment_results
compare_configs
write_comparison
ComparisonResult
ConfigSummary
```
