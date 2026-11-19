# ticket-038 Add Training Progress Monitoring

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify callback performance does not impact training speed)

## Context

### Background

After completing Epics 01-08, the SDDPlab training pipeline calls `SDDP.train(model.policy_graph; train_kwargs...)` in `src/Engines/sddp/train.jl` (line 31) and discards the return value (which is `nothing`). The convergence data is only accessible post-training via `SDDP.write_log_to_csv()` in `save_policy.jl`. There is no way for users to configure SDDP.jl's built-in logging behaviour (log file path, log frequency, print level) through the JSONC configuration, and the rich per-iteration training log stored in `model.most_recent_training_results` is never captured or exposed.

This ticket adds a `TrainingLogConfig` struct to the engine configuration that controls SDDP.jl's `log_file`, `log_frequency`, `log_every_iteration`, and `print_level` kwargs, and captures the structured training log from the `PolicyGraph.most_recent_training_results` field after training completes. The captured log is returned as part of the `SDDPPolicyTaskArtifact` and saved alongside policy output files.

### Relation to Epic

This is the foundation ticket for Epic 09 (Observability and Diagnostics). It exposes SDDP.jl's built-in logging configuration and captures the structured training log that ticket-039 (convergence analysis) and ticket-040 (subproblem debugging) will build upon.

### Current State

- `src/Engines/sddp/train.jl`: `Lab.train()` returns `SDDPPolicyTaskArtifact(model.policy_graph)`. No logging kwargs are passed to `SDDP.train()`. The return value is discarded.
- `src/Engines/Engines.jl`: `SDDPPolicyTaskArtifact` has a single field `policy::SDDP.PolicyGraph`.
- `src/Engines/sddp/save_policy.jl`: `__get_model_convergence()` reads `SDDP.write_log_to_csv()` to a temp file, then parses it back. This is a workaround for not having the structured log.
- `SDDPEngine` has 6 fields: `policy`, `simulation`, `diagnostics`, `solver`, `inflow_non_negativity`, `validation`.
- SDDP.jl stores training results in `model.most_recent_training_results::TrainingResults` with fields `status::Symbol` and `log::Vector{SDDP.Log}`. Each `SDDP.Log` has: `iteration::Int`, `bound::Float64`, `simulation_value::Float64`, `time::Float64`, `pid::Int`, `total_solves::Int`, `duality_key::String`, `serious_numerical_issue::Bool`.

## Specification

### Requirements

1. **New struct `TrainingLogConfig`** with fields:
   - `log_file::String` (default `""` meaning no log file)
   - `log_frequency::Int` (default `1`)
   - `log_every_iteration::Bool` (default `false`)
   - `print_level::Int` (default `1`)

2. **New struct `TrainingLog`** to hold the captured structured log:
   - `status::Symbol` (training termination status)
   - `iterations::Vector{TrainingLogEntry}` (per-iteration data)

3. **New struct `TrainingLogEntry`** with fields matching `SDDP.Log`:
   - `iteration::Int`
   - `bound::Float64`
   - `simulation_value::Float64`
   - `time::Float64`
   - `total_solves::Int`
   - `serious_numerical_issue::Bool`

4. **Extend `SDDPPolicyTaskArtifact`** to carry the training log:
   - Add field `training_log::Union{TrainingLog, Nothing}` (Nothing when log cannot be captured)

5. **Wire logging kwargs** from `TrainingLogConfig` into `SDDP.train()` call in `train.jl`.

6. **Capture the training log** after `SDDP.train()` completes by reading `model.policy_graph.most_recent_training_results`.

7. **Save training log** as a CSV/Parquet file (`training_log.csv` or `.parquet`) alongside policy output in `save_policy.jl`.

8. **Configuration**: `TrainingLogConfig` lives under `"policy"` sub-dict as an optional `"logging"` key. Default is constructed when the key is absent.

### Inputs/Props

JSONC configuration example:

```jsonc
{
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      "policy": {
        "convergence": { ... },
        "risk_measure": { ... },
        "parallel_scheme": { ... },
        // NEW: optional logging config
        "logging": {
          "log_file": "training.log",
          "log_frequency": 1,
          "log_every_iteration": false,
          "print_level": 1
        }
      }
    }
  }
}
```

### Outputs/Behavior

- When `logging` key is absent: defaults applied (no log file, frequency=1, print_level=1, log_every_iteration=false)
- When `log_file` is non-empty: SDDP.jl writes a live log file during training
- After training: `SDDPPolicyTaskArtifact` contains a `TrainingLog` with all per-iteration data
- `save_policy` writes `training_log.csv` (or `.parquet`) with columns: `iteration`, `bound`, `simulation_value`, `time`, `total_solves`, `serious_numerical_issue`
- The existing `__get_model_convergence()` function remains as-is for backward compatibility

### Error Handling

- If `model.policy_graph.most_recent_training_results` is `nothing` (e.g., training was never called), set `training_log` to `nothing` in the artifact
- If accessing the training results throws, catch the exception, `@warn`, and set `training_log` to `nothing`
- All new constructors follow the `Dict{String,Any}` + `CompositeException` pattern, returning `nothing` on failure

## Acceptance Criteria

- [ ] Given a JSONC config with no `logging` key under `policy`, when `Study()` is constructed, then `SDDPPolicyTaskDefinition` has a `TrainingLogConfig` with default values (log_file="", log_frequency=1, log_every_iteration=false, print_level=1)
- [ ] Given a JSONC config with a `logging` key specifying `log_file: "train.log"` and `print_level: 0`, when training runs, then SDDP.jl creates a `train.log` file and prints nothing to console
- [ ] Given a successful training run, when `Lab.train()` returns, then `SDDPPolicyTaskArtifact.training_log` is a `TrainingLog` with `status != :model_not_solved` and a non-empty `iterations` vector
- [ ] Given a `SDDPPolicyTaskArtifact` with a non-nothing `training_log`, when `save_policy` is called, then a `training_log.csv` (or `.parquet`) file is written with one row per iteration and correct columns
- [ ] Given invalid `logging` config (e.g., `log_frequency: -1`), when `Study()` is constructed, then appropriate validation errors are accumulated in `CompositeException`

## Implementation Guide

### Suggested Approach

1. **Define types** in `src/Engines/Engines.jl`:
   - Add `TrainingLogConfig` struct (4 fields)
   - Add `TrainingLogEntry` struct (6 fields)
   - Add `TrainingLog` struct (2 fields: `status::Symbol`, `iterations::Vector{TrainingLogEntry}`)
   - Modify `SDDPPolicyTaskArtifact` to add `training_log::Union{TrainingLog, Nothing}` field
   - Add `TrainingLogConfig` field to `SDDPPolicyTaskDefinition` (becomes 9 fields)
   - Export new types

2. **Add constructors and validators** following the 6-step recipe:
   - `TrainingLogConfig(d::Dict{String,Any}, e::CompositeException)` in `src/Engines/sddp/input.jl`
   - `TRAINING_LOG_CONFIG_SCHEMA` in `src/Engines/sddp/input-validators.jl`
   - `__build_logging!` builder function in `src/Engines/sddp/input.jl`
   - Call `__build_logging!` from `__build_sddp_policy_task_definition_internals_from_dicts!`
   - Add `"logging"` to `__validate_sddp_policy_task_definition_keys_types!`

3. **Wire kwargs in train.jl**:
   - Extract `logging::TrainingLogConfig` from `definition`
   - Add `log_file`, `log_frequency`, `log_every_iteration`, `print_level` to `train_kwargs` Dict
   - Only add `log_file` when it is non-empty
   - After `SDDP.train()`, capture `model.policy_graph.most_recent_training_results`
   - Convert `SDDP.Log` entries to `TrainingLogEntry` entries
   - Return `SDDPPolicyTaskArtifact(model.policy_graph, training_log)`

4. **Save training log in save_policy.jl**:
   - Add `__write_training_log` function that converts `TrainingLog` to a DataFrame and writes it
   - Call from `Lab.save_policy` when `artifact.training_log !== nothing`

5. **Update study.jl**:
   - `train()` and `save_policy()` function signatures are unchanged (they use `PolicyTaskArtifact` abstract type)
   - No changes needed to study.jl since it passes artifact through

6. **Update Experiments runner** if it accesses `SDDPPolicyTaskArtifact.policy` directly (check `src/Experiments/runner.jl`)

### Key Files to Modify

- `src/Engines/Engines.jl` -- add structs, modify `SDDPPolicyTaskArtifact` and `SDDPPolicyTaskDefinition`, update exports
- `src/Engines/sddp/input.jl` -- add `TrainingLogConfig` constructor, `__build_logging!`
- `src/Engines/sddp/input-validators.jl` -- add `TRAINING_LOG_CONFIG_SCHEMA`, update engine validators
- `src/Engines/sddp/train.jl` -- wire logging kwargs, capture training results
- `src/Engines/sddp/save_policy.jl` -- add `__write_training_log`, call from `Lab.save_policy`
- `src/Engines/sddp.jl` -- no changes needed (includes are already in place)
- `src/Experiments/runner.jl` -- check if it accesses `SDDPPolicyTaskArtifact` fields directly; update if needed

### Patterns to Follow

- Follow the exact `Dict{String,Any}` + `CompositeException` constructor pattern used by `DiagnosticsConfig` in `src/Engines/sddp/input.jl` lines 1-14
- Follow the `__build_*!` pattern used by `__build_diagnostics!` for optional config with defaults
- Follow the `FieldRule` schema pattern in `input-validators.jl` (e.g., `DIAGNOSTICS_SCHEMA`)
- The `SDDPPolicyTaskDefinition` constructor in `input.jl` lines 292-311 shows how to wire new fields

### Pitfalls to Avoid

- `SDDP.train()` returns `nothing` -- do NOT try to capture its return value. Instead, access `model.policy_graph.most_recent_training_results` after the call.
- `model.most_recent_training_results` lives on `PolicyGraph`, not on `SDDP.Model`. Access it as `model.policy_graph.most_recent_training_results` since `model` is an `SDDPModel`.
- The `SDDP.Log` struct fields may differ across SDDP.jl versions. Wrap the conversion in `try-catch` and degrade gracefully.
- Adding a field to `SDDPPolicyTaskArtifact` changes its constructor call in `train.jl` and potentially in `simulate.jl` (check all call sites).
- Do NOT modify `__get_model_convergence()` in `save_policy.jl` -- keep it for backward compatibility.
- When `log_file` is empty string, do NOT pass the kwarg to `SDDP.train()` (passing `""` may create an empty file).
- The Experiments runner (`src/Experiments/runner.jl`) may directly construct or pattern-match on `SDDPPolicyTaskArtifact` -- verify and update.

## Testing Requirements

### Unit Tests

Create `test/test-training-log.jl`:

- Test `TrainingLogConfig` default constructor (no dict keys)
- Test `TrainingLogConfig` with all fields specified
- Test `TrainingLogConfig` with invalid values (negative `log_frequency`, `print_level` out of range)
- Test `SDDPPolicyTaskDefinition` construction with and without `logging` key
- Test `TrainingLogEntry` creation from mock data
- Test `TrainingLog` creation

### Integration Tests

In the same file, using `example/1dtoy` with `max_iterations: 3`:

- Test that `Lab.train()` returns artifact with non-nothing `training_log`
- Test that `training_log.iterations` has the expected number of entries (may be less than or equal to `max_iterations`)
- Test that `save_policy` writes `training_log.csv` file
- Test that the written CSV has correct columns
- Test with `log_file` configured -- verify the file is created
- Test with `print_level: 0` -- verify no console output (check stderr capture)

Use `mktempdir() do tmpdir ... end` for output tests.
Use `TEST_FILTER="test-training-log"` with 180000ms timeout.

### E2E Tests

Not required for this ticket.

## Dependencies

- **Blocked By**: ticket-037 (Epic 08 complete)
- **Blocks**: ticket-039

## Effort Estimate

**Points**: 3
**Confidence**: High
