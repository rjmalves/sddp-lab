# ticket-037 Add Reproducibility Infrastructure

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify reproducibility handles SDDP-specific non-determinism)

## Context

### Background

Reproducibility is a key requirement for computational experiments. SDDPlab already manages random seeds for SAA generation (in `ScenariosData` and in `OutOfSampleValidation`) and uses deterministic graph construction. However, when running experiments (ticket-034) or sensitivity analyses (ticket-035), there is no systematic recording of the environment, configuration, and metadata needed to reproduce results later.

This ticket adds reproducibility infrastructure that captures a snapshot of the execution environment and the exact configuration used for each run, writing this metadata alongside the results. It also adds a configuration hashing mechanism so that runs can be identified and deduplicated.

### Relation to Epic

This is the final ticket in Epic 08. It enhances the output of the experiment runner (ticket-034) and comparison tools (ticket-036) with metadata that enables reproducibility and provenance tracking.

### Current State

After tickets 034-036:

- `src/Experiments/Experiments.jl` module provides `run_experiment`, `run_sensitivity`, `aggregate_experiment_results`, `write_comparison`
- Each config run saves results in `<output_dir>/<config_name>/`
- `experiment_summary.csv` and `comparison_summary.csv` exist but contain no environment or version metadata
- Seeds are already managed: `ScenariosData` carries a seed for SAA generation; `OutOfSampleValidation` has its own seed; per-Markov-state seeds use prime offsets
- The `Study` struct holds `InputsData` (path + files) and `Engine` -- the full configuration is available in memory
- `src/SDDPlab.jl` defines the top-level module; Julia's `Pkg` API can inspect the current manifest

## Specification

### Requirements

1. Create `src/Experiments/reproducibility.jl` with reproducibility utilities
2. Implement `capture_environment()::EnvironmentSnapshot` that records:
   - Julia version (`VERSION`)
   - OS and architecture (`Sys.MACHINE`)
   - Key package versions: SDDP.jl, JuMP.jl, HiGHS.jl (read from `Pkg.dependencies()`)
   - Number of threads (`Threads.nthreads()`)
   - Timestamp (ISO 8601)
3. Implement `hash_config(config_dict::Dict{String,Any})::String` that produces a deterministic SHA-256 hash of the JSON-serialized configuration (sorted keys, no whitespace). This allows identifying identical configurations across runs.
4. Implement `write_run_metadata(output_dir::String, config_name::String, config_dict::Dict{String,Any}, env::EnvironmentSnapshot)` that writes `metadata.json` to `<output_dir>/<config_name>/metadata.json` containing:
   - `config_hash`: the SHA-256 hash
   - `config`: the full engine configuration as-is
   - `environment`: the environment snapshot
   - `timestamp`: when the run started
5. Integrate metadata writing into the experiment runner: after each successful config run, call `write_run_metadata` to save the metadata alongside the results
6. Implement `verify_reproducibility(dir_a::String, dir_b::String)::Bool` that reads `metadata.json` from two run directories and compares config hashes. Returns `true` if configs are identical, `false` otherwise. Logs differences in environment if configs match but environments differ.
7. Add a `seeds` section to `metadata.json` that captures all seeds used (SAA seed, validation seed if applicable, per-Markov-state derived seeds).

### Inputs/Props

- `capture_environment()` takes no arguments
- `hash_config(config_dict)` takes the raw engine params dict before Study construction
- `write_run_metadata(...)` takes the output directory, config name, raw config dict, and environment snapshot
- `verify_reproducibility(dir_a, dir_b)` takes two output directories

### Outputs/Behavior

- `EnvironmentSnapshot` struct:
  - `julia_version::String`
  - `os_machine::String`
  - `package_versions::Dict{String,String}` (package name -> version string)
  - `num_threads::Int`
  - `timestamp::String` (ISO 8601)
- `metadata.json` per run directory:
  ```json
  {
      "config_hash": "a1b2c3d4...",
      "config": { ... },
      "environment": {
          "julia_version": "1.10.2",
          "os_machine": "x86_64-linux-gnu",
          "package_versions": {
              "SDDP": "1.8.1",
              "JuMP": "1.23.0",
              "HiGHS": "1.12.0"
          },
          "num_threads": 4,
          "timestamp": "2026-02-19T15:30:00Z"
      },
      "seeds": {
          "saa_seed": 12345,
          "validation_seed": null
      }
  }
  ```
- `verify_reproducibility` returns `Bool` and logs diagnostics

### Error Handling

- `Pkg.dependencies()` may fail in non-standard environments: wrap in try-catch, record "unknown" for package versions
- `metadata.json` write failure: log a warning but do NOT fail the experiment run
- `verify_reproducibility` with missing `metadata.json`: return `false` with a warning

## Acceptance Criteria

- [ ] C1: Given a successful experiment run, when the run completes, then each config subdirectory contains a `metadata.json` file with non-empty `config_hash`, `config`, `environment`, and `seeds` sections
- [ ] C2: Given two runs with identical engine configurations, when `hash_config` is called on each, then the hashes are identical
- [ ] C3: Given two runs with different risk measures but otherwise identical configs, when `hash_config` is called on each, then the hashes differ
- [ ] C4: Given `capture_environment()`, when called, then `julia_version` matches `string(VERSION)` and `num_threads` matches `Threads.nthreads()`
- [ ] C5: Given two run directories with `metadata.json` files that have the same `config_hash`, when `verify_reproducibility` is called, then it returns `true`
- [ ] C6: Given a run directory without `metadata.json`, when `verify_reproducibility` is called, then it returns `false` with a `@warn`

## Implementation Guide

### Suggested Approach

1. Create `src/Experiments/reproducibility.jl` with:

   ```julia
   using SHA  # Julia stdlib
   using Pkg

   struct EnvironmentSnapshot
       julia_version::String
       os_machine::String
       package_versions::Dict{String,String}
       num_threads::Int
       timestamp::String
   end

   function capture_environment()::EnvironmentSnapshot
       pkg_versions = Dict{String,String}()
       try
           deps = Pkg.dependencies()
           for (_, info) in deps
               if info.name in ["SDDP", "JuMP", "HiGHS", "GLPK", "DataFrames", "CSV"]
                   pkg_versions[info.name] = string(info.version)
               end
           end
       catch
           @warn "Could not read package versions"
       end
       return EnvironmentSnapshot(
           string(VERSION),
           Sys.MACHINE,
           pkg_versions,
           Threads.nthreads(),
           Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SSZ"),
       )
   end
   ```

2. Implement `hash_config`:

   ```julia
   function hash_config(config_dict::Dict{String,Any})::String
       # Serialize with sorted keys for determinism
       json_str = JSON.json(config_dict, 0)  # 0 = no indent, compact
       return bytes2hex(SHA.sha256(Vector{UInt8}(json_str)))
   end
   ```

   Note: `JSON.json` sorts keys by default in Julia's JSON.jl. Verify this. If not, implement a recursive key-sort before serialization.

3. Implement `write_run_metadata`:

   ```julia
   function write_run_metadata(
       output_dir::String,
       config_name::String,
       config_dict::Dict{String,Any},
       env::EnvironmentSnapshot;
       seeds::Dict{String,Any} = Dict{String,Any}(),
   )
       metadata = Dict{String,Any}(
           "config_hash" => hash_config(config_dict),
           "config" => config_dict,
           "environment" => Dict{String,Any}(
               "julia_version" => env.julia_version,
               "os_machine" => env.os_machine,
               "package_versions" => env.package_versions,
               "num_threads" => env.num_threads,
               "timestamp" => env.timestamp,
           ),
           "seeds" => seeds,
       )
       filepath = joinpath(output_dir, config_name, "metadata.json")
       try
           open(filepath, "w") do io
               JSON.print(io, metadata, 2)
           end
       catch ex
           @warn "Failed to write metadata" config_name exception = ex
       end
   end
   ```

4. Integrate into `_run_single_config` in `src/Experiments/runner.jl`: after saving results, call `write_run_metadata`. Pass the raw config dict (before Study construction) and capture seeds from the Study's scenarios data.

5. Implement `verify_reproducibility` that loads both `metadata.json` files, compares hashes, and logs environment differences.

6. SHA is in Julia stdlib (`using SHA`), so no new dependency is needed.

### Key Files to Create/Modify

| File                                       | Action | Description                                                                                                 |
| ------------------------------------------ | ------ | ----------------------------------------------------------------------------------------------------------- |
| `src/Experiments/reproducibility.jl`       | Create | `EnvironmentSnapshot`, `capture_environment`, `hash_config`, `write_run_metadata`, `verify_reproducibility` |
| `src/Experiments/Experiments.jl`           | Modify | Add `include("reproducibility.jl")` and exports                                                             |
| `src/Experiments/runner.jl`                | Modify | Call `write_run_metadata` after each config run in `_run_single_config`                                     |
| `src/SDDPlab.jl`                           | Modify | Add reproducibility exports                                                                                 |
| `test/Experiments/test-reproducibility.jl` | Create | Tests for reproducibility infrastructure                                                                    |

### Patterns to Follow

- Use `JSON.print(io, dict, indent)` for writing JSON (consistent with the project's use of JSON.jl)
- Use `SHA.sha256` from Julia stdlib for hashing
- Use `Pkg.dependencies()` for package version introspection
- Use `Dates.format` for ISO 8601 timestamps (Dates.jl is already imported in Engines module)
- Error handling: metadata write failure should NEVER abort the experiment -- wrap in try-catch with @warn

### Pitfalls to Avoid

- **JSON key ordering**: `JSON.json` in JSON.jl does NOT sort keys by default. You must implement a recursive sort-keys function before serialization to ensure deterministic hashing. Without this, identical configs can produce different hashes.
- **Float precision**: JSON serialization of Float64 values may differ across platforms. Use a canonical format (e.g., `round(x, digits=15)`) before hashing if needed.
- **Pkg.dependencies() in test environments**: This call may return different results depending on whether the test runs in the project environment or a temporary test environment. The tests should mock or accept both cases.
- **Thread count as reproducibility factor**: `Threads.nthreads()` affects results when using `SDDP.Threaded()` because SDDP's parallel forward passes may explore different sample paths. `verify_reproducibility` should WARN (not fail) when thread counts differ.
- **Do NOT modify the core pipeline** -- all changes are in the Experiments module and the runner integration point.

## Testing Requirements

### Unit Tests

- `hash_config` produces identical hashes for identical dicts
- `hash_config` produces different hashes for dicts that differ in one leaf value
- `hash_config` produces identical hashes regardless of key insertion order (tests the sort-keys requirement)
- `capture_environment` returns a valid `EnvironmentSnapshot` with non-empty julia_version
- `verify_reproducibility` returns `true` for matching metadata files and `false` for mismatched ones

### Integration Tests

- Run a 1-config experiment on `example/1dtoy` (max_iterations: 3), verify `metadata.json` exists and is valid JSON with all required sections
- Run the same config twice, verify `config_hash` is identical across both runs
- **Use `TEST_FILTER="test-reproducibility"` and 180000ms Bash timeout**

### E2E Tests

Not applicable.

## Dependencies

- **Blocked By**: ticket-034 (experiment runner must exist for integration); ticket-036 is a soft dependency (comparison tools benefit from metadata but do not require it)
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: High
