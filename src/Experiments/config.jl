const _VALID_CONFIG_NAME_RE = r"^[a-zA-Z0-9_-]+$"

"""
    read_experiment_config(path) -> ExperimentConfig

Parse and validate an `experiment.jsonc` file located at `path`.

Required top-level keys: `"base_study"`, `"configurations"`.
Optional key: `"output_dir"` (default: `"results"` relative to the jsonc file's directory),
`"overwrite"` (default: `false`).

Config names must match `^[a-zA-Z0-9_-]+\$` (alphanumeric, underscore, hyphen).

Errors are accumulated via `CompositeException` and thrown together when validation fails.

# Example

```julia
cfg = read_experiment_config("/path/to/experiment.jsonc")
```
"""
function read_experiment_config(path::String)::ExperimentConfig
    e = CompositeException()

    abs_path = abspath(path)
    experiment_dir = dirname(abs_path)

    d = nothing
    original_pwd = pwd()
    try
        cd(experiment_dir)
        d = read_jsonc(basename(abs_path), e)
    finally
        cd(original_pwd)
    end

    d === nothing && throw(e)

    if !haskey(d, "base_study")
        push!(e, ErrorException("experiment.jsonc is missing required key \"base_study\""))
    end
    if !haskey(d, "configurations")
        push!(
            e, ErrorException("experiment.jsonc is missing required key \"configurations\"")
        )
    end
    !isempty(e) && throw(e)

    raw_base = d["base_study"]
    if !(raw_base isa String)
        push!(e, ErrorException("\"base_study\" must be a String, got $(typeof(raw_base))"))
        throw(e)
    end

    base_study_path =
        isabspath(raw_base) ? raw_base : normpath(joinpath(experiment_dir, raw_base))

    if !isdir(base_study_path)
        push!(e, ErrorException("base_study directory not found: \"$base_study_path\""))
    end
    if !isfile(joinpath(base_study_path, "main.jsonc"))
        push!(
            e,
            ErrorException(
                "base_study directory \"$base_study_path\" does not contain a main.jsonc"
            ),
        )
    end

    raw_output = get(d, "output_dir", "results")
    if !(raw_output isa String)
        push!(
            e, ErrorException("\"output_dir\" must be a String, got $(typeof(raw_output))")
        )
        raw_output = "results"
    end
    output_dir =
        isabspath(raw_output) ? raw_output : normpath(joinpath(experiment_dir, raw_output))

    overwrite = get(d, "overwrite", false)
    if !(overwrite isa Bool)
        push!(e, ErrorException("\"overwrite\" must be a Bool, got $(typeof(overwrite))"))
        overwrite = false
    end

    raw_configs = d["configurations"]
    if !(raw_configs isa Dict)
        push!(
            e,
            ErrorException("\"configurations\" must be a Dict, got $(typeof(raw_configs))"),
        )
        throw(e)
    end

    configurations = Vector{Tuple{String,Dict{String,Any}}}()

    for (name, overrides) in raw_configs
        if !occursin(_VALID_CONFIG_NAME_RE, name)
            push!(
                e,
                ErrorException(
                    "Invalid configuration name \"$name\": names must match " *
                    "^[a-zA-Z0-9_-]+\$ (alphanumeric, underscore, hyphen only)",
                ),
            )
            continue
        end

        if !(overrides isa Dict)
            push!(
                e,
                ErrorException(
                    "Configuration \"$name\" must be a Dict, got $(typeof(overrides))"
                ),
            )
            continue
        end

        push!(configurations, (name, convert(Dict{String,Any}, overrides)))
    end

    !isempty(e) && throw(e)

    return ExperimentConfig(base_study_path, output_dir, configurations, overwrite)
end
