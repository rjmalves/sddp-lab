"""
    ExperimentConfig

Holds the parsed and validated contents of an `experiment.jsonc` file.

# Fields

  - `base_study_path`: Absolute path to the base study directory (contains `main.jsonc`).
  - `output_dir`: Absolute path where per-configuration result subdirectories will be written.
  - `configurations`: Ordered dict mapping config name -> engine-params override dict.
  - `overwrite`: When `true`, allows writing into a non-empty output directory.

# Example

```julia
config = read_experiment_config("/path/to/experiment.jsonc")
```
"""
struct ExperimentConfig
    base_study_path::String
    output_dir::String
    configurations::Vector{Tuple{String,Dict{String,Any}}}
    overwrite::Bool
end

"""
    ExperimentResult

Records the outcome of running a single named configuration.

# Fields

  - `config_name`: Name of the configuration (used as subdirectory name).
  - `output_path`: Absolute path to the directory where results were saved.
  - `train_elapsed_seconds`: Wall-clock time (seconds) spent in `train`.
  - `simulate_elapsed_seconds`: Wall-clock time (seconds) spent in `simulate`.
  - `success`: `true` if the configuration completed without error.
  - `error_message`: Error description when `success == false`, `nothing` otherwise.
"""
struct ExperimentResult
    config_name::String
    output_path::String
    train_elapsed_seconds::Float64
    simulate_elapsed_seconds::Float64
    success::Bool
    error_message::Union{String,Nothing}
end
