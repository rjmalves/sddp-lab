# Observability

The observability module provides tools for monitoring SDDP training convergence
and ensuring reproducibility of experiment runs.

## Environment Capture

```@docs
EnvironmentSnapshot
capture_environment
```

## Config Hashing and Metadata

```@docs
hash_config
write_run_metadata
verify_reproducibility
```

## Convergence Analysis

These functions analyze [`TrainingLog`](@ref) data produced by
[`train`](@ref) to diagnose convergence quality.

```@docs
compute_gap_trajectory
compute_convergence_rate
detect_bound_stationarity
generate_convergence_report
```
