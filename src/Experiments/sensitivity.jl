using CSV

"""
    SensitivityParameter

Describes a single parameter to sweep in a sensitivity analysis.

# Fields

  - `label`: Human-readable name used in config names and the summary CSV.
  - `path`: Dot-separated path into the engine params dict
    (e.g., `"policy.risk_measure"` or `"simulation.num_simulated_series"`).
  - `values`: Non-empty list of values to sweep over. Each value may be a
    scalar (`Int`, `Float64`, `String`) or a `Dict{String,Any}` for structured
    objects such as risk measures.
"""
struct SensitivityParameter
    label::String
    path::String
    values::Vector{Any}
end

"""
    SensitivityConfig

Holds the parsed and validated contents of a `sensitivity.jsonc` file.

# Fields

  - `base_study`: Absolute path to the base study directory (contains `main.jsonc`).
  - `output_dir`: Absolute path where per-configuration result subdirectories will be
    written.
  - `mode`: `"oat"` (one-at-a-time, default) or `"factorial"` (full factorial).
  - `base_overrides`: Engine-params overrides applied to every generated configuration
    before the per-parameter override is applied.
  - `parameters`: Ordered list of `SensitivityParameter` definitions.
  - `overwrite`: When `true`, allows writing into a non-empty output directory.

# Example

```julia
config = read_sensitivity_config("/path/to/sensitivity.jsonc")
```
"""
struct SensitivityConfig
    base_study::String
    output_dir::String
    mode::String
    base_overrides::Dict{String,Any}
    parameters::Vector{SensitivityParameter}
    overwrite::Bool
end

"""
    SensitivityResult

Records the outcome of a complete sensitivity analysis run.

# Fields

  - `mode`: `"oat"` or `"factorial"` — the sweep mode that was used.
  - `parameters`: The `SensitivityParameter` definitions from the config.
  - `results`: One `ExperimentResult` per generated configuration.
  - `summary_path`: Absolute path to the `sensitivity_summary.csv` written after the run.
"""
struct SensitivityResult
    mode::String
    parameters::Vector{SensitivityParameter}
    results::Vector{ExperimentResult}
    summary_path::String
end

"""
    read_sensitivity_config(path) -> SensitivityConfig

Parse and validate a `sensitivity.jsonc` file at `path`.

Required top-level keys: `"base_study"`, `"parameters"`.
Optional keys: `"output_dir"` (default: `"sensitivity_results"` relative to the
jsonc file's directory), `"mode"` (default: `"oat"`), `"base_overrides"` (default:
empty dict), `"overwrite"` (default: `false`).

Each entry in `"parameters"` must have:

  - `"path"`: non-empty String (dot-separated path into engine params)
  - `"values"`: non-empty Array
  - `"label"`: non-empty String

Errors are accumulated via `CompositeException` and thrown together when
validation fails.

# Example

```julia
cfg = read_sensitivity_config("/path/to/sensitivity.jsonc")
```
"""
function read_sensitivity_config(path::String)::SensitivityConfig
    e = CompositeException()

    abs_path = abspath(path)
    sensitivity_dir = dirname(abs_path)

    d = nothing
    original_pwd = pwd()
    try
        cd(sensitivity_dir)
        d = read_jsonc(basename(abs_path), e)
    finally
        cd(original_pwd)
    end

    d === nothing && throw(e)

    if !haskey(d, "base_study")
        push!(e, ErrorException("sensitivity.jsonc is missing required key \"base_study\""))
    end
    if !haskey(d, "parameters")
        push!(e, ErrorException("sensitivity.jsonc is missing required key \"parameters\""))
    end
    !isempty(e) && throw(e)

    raw_base = d["base_study"]
    if !(raw_base isa String)
        push!(e, ErrorException("\"base_study\" must be a String, got $(typeof(raw_base))"))
        throw(e)
    end

    base_study =
        isabspath(raw_base) ? raw_base : normpath(joinpath(sensitivity_dir, raw_base))

    if !isdir(base_study)
        push!(e, ErrorException("base_study directory not found: \"$base_study\""))
    end
    if !isfile(joinpath(base_study, "main.jsonc"))
        push!(
            e,
            ErrorException(
                "base_study directory \"$base_study\" does not contain a main.jsonc"
            ),
        )
    end

    raw_output = get(d, "output_dir", "sensitivity_results")
    if !(raw_output isa String)
        push!(
            e, ErrorException("\"output_dir\" must be a String, got $(typeof(raw_output))")
        )
        raw_output = "sensitivity_results"
    end
    output_dir =
        isabspath(raw_output) ? raw_output : normpath(joinpath(sensitivity_dir, raw_output))

    mode = get(d, "mode", "oat")
    if !(mode isa String)
        push!(e, ErrorException("\"mode\" must be a String, got $(typeof(mode))"))
        mode = "oat"
    elseif mode != "oat" && mode != "factorial"
        push!(e, ErrorException("\"mode\" must be \"oat\" or \"factorial\", got \"$mode\""))
        mode = "oat"
    end

    raw_overrides = get(d, "base_overrides", Dict{String,Any}())
    if !(raw_overrides isa Dict)
        push!(
            e,
            ErrorException(
                "\"base_overrides\" must be a Dict, got $(typeof(raw_overrides))"
            ),
        )
        raw_overrides = Dict{String,Any}()
    end
    base_overrides = convert(Dict{String,Any}, raw_overrides)

    overwrite = get(d, "overwrite", false)
    if !(overwrite isa Bool)
        push!(e, ErrorException("\"overwrite\" must be a Bool, got $(typeof(overwrite))"))
        overwrite = false
    end

    raw_params = d["parameters"]
    if !(raw_params isa Vector)
        push!(
            e, ErrorException("\"parameters\" must be an Array, got $(typeof(raw_params))")
        )
        throw(e)
    end
    if isempty(raw_params)
        push!(e, ErrorException("\"parameters\" must not be empty"))
        throw(e)
    end

    parameters = SensitivityParameter[]

    for (idx, raw_p) in enumerate(raw_params)
        if !(raw_p isa Dict)
            push!(
                e, ErrorException("parameters[$idx] must be a Dict, got $(typeof(raw_p))")
            )
            continue
        end

        if !haskey(raw_p, "path")
            push!(e, ErrorException("parameters[$idx] is missing required key \"path\""))
        elseif !(raw_p["path"] isa String) || isempty(raw_p["path"])
            push!(
                e,
                ErrorException(
                    "parameters[$idx].path must be a non-empty String, got $(repr(raw_p["path"]))",
                ),
            )
        end

        if !haskey(raw_p, "label")
            push!(e, ErrorException("parameters[$idx] is missing required key \"label\""))
        elseif !(raw_p["label"] isa String) || isempty(raw_p["label"])
            push!(
                e,
                ErrorException(
                    "parameters[$idx].label must be a non-empty String, got $(repr(raw_p["label"]))",
                ),
            )
        end

        if !haskey(raw_p, "values")
            push!(e, ErrorException("parameters[$idx] is missing required key \"values\""))
        elseif !(raw_p["values"] isa Vector)
            push!(
                e,
                ErrorException(
                    "parameters[$idx].values must be an Array, got $(typeof(raw_p["values"]))",
                ),
            )
        elseif isempty(raw_p["values"])
            push!(e, ErrorException("parameters[$idx].values must not be empty"))
        end

        !isempty(e) && continue

        push!(
            parameters,
            SensitivityParameter(
                raw_p["label"], raw_p["path"], convert(Vector{Any}, raw_p["values"])
            ),
        )
    end

    !isempty(e) && throw(e)

    return SensitivityConfig(
        base_study, output_dir, mode, base_overrides, parameters, overwrite
    )
end

"""
    run_sensitivity(config_path) -> SensitivityResult

Read a `sensitivity.jsonc` at `config_path`, generate all configurations
according to the sweep mode, execute each through the full
`build -> train -> simulate -> save` pipeline, and write
`sensitivity_summary.csv` to the output directory.

Individual configuration failures are caught and recorded; all configurations
are always attempted. Returns a `SensitivityResult` with per-config outcomes
and the path to the summary CSV.

# Example

```julia
result = run_sensitivity("/path/to/sensitivity.jsonc")
println("Mode: ", result.mode)
for r in result.results
    println(r.config_name, ": ", r.success ? "ok" : r.error_message)
end
```
"""
function run_sensitivity(config_path::String)::SensitivityResult
    config = read_sensitivity_config(config_path)

    configs = if config.mode == "oat"
        _generate_oat_configs(config.base_overrides, config.parameters)
    else
        _generate_factorial_configs(config.base_overrides, config.parameters)
    end

    if config.mode == "factorial" && length(configs) > 100
        @warn "Factorial sensitivity produces $(length(configs)) combinations — this may take a long time"
    end

    _prepare_output_dir(config.output_dir, config.overwrite)

    results = ExperimentResult[]
    for (config_name, overrides) in configs
        @info "Running sensitivity configuration: $config_name"
        result = _run_single_config(
            config.base_study, config_name, overrides, config.output_dir
        )
        push!(results, result)
        if result.success
            @info "Sensitivity configuration \"$config_name\" completed" train_s =
                result.train_elapsed_seconds simulate_s = result.simulate_elapsed_seconds
        else
            @warn "Sensitivity configuration \"$config_name\" failed" error =
                result.error_message
        end
    end

    summary_path = _write_sensitivity_summary(config.output_dir, results, configs, config)
    return SensitivityResult(config.mode, config.parameters, results, summary_path)
end

function _resolve_path(dict::Dict, dotpath::String)
    keys_list = split(dotpath, ".")
    current = dict
    for k in keys_list
        !(current isa Dict) && return nothing
        !haskey(current, k) && return nothing
        current = current[k]
    end
    return current
end

function _set_path!(dict::Dict, dotpath::String, value)
    keys_list = split(dotpath, ".")
    current = dict
    for k in keys_list[1:(end - 1)]
        if !haskey(current, k) || !(current[k] isa Dict)
            current[k] = Dict{String,Any}()
        end
        current = current[k]
    end
    current[keys_list[end]] = value
    return dict
end

function _sanitize_config_name(s::String)::String
    result = lowercase(s)
    result = replace(result, r"[^a-z0-9_-]" => "_")
    result = replace(result, r"_+" => "_")
    result = strip(result, '_')
    result = String(result)  # strip returns SubString; ensure concrete String
    result = first(result, 60)
    result = strip(result, '_')
    result = String(result)
    return isempty(result) ? "config" : result
end

function _generate_oat_configs(
    base_overrides::Dict{String,Any}, parameters::Vector{SensitivityParameter}
)::Vector{Tuple{String,Dict{String,Any}}}
    configs = Tuple{String,Dict{String,Any}}[]
    seen_names = Dict{String,Int}()

    for param in parameters
        for value in param.values
            overrides = deepcopy(base_overrides)
            _set_path!(overrides, param.path, value)

            raw_name = _sanitize_config_name("$(param.label)_$(value)")
            name = _unique_name(raw_name, seen_names)

            push!(configs, (name, overrides))
        end
    end

    return configs
end

function _generate_factorial_configs(
    base_overrides::Dict{String,Any}, parameters::Vector{SensitivityParameter}
)::Vector{Tuple{String,Dict{String,Any}}}
    configs = Tuple{String,Dict{String,Any}}[]
    seen_names = Dict{String,Int}()

    value_ranges = [param.values for param in parameters]
    for combo in Iterators.product(value_ranges...)
        overrides = deepcopy(base_overrides)
        name_parts = String[]

        for (param, value) in zip(parameters, combo)
            _set_path!(overrides, param.path, value)
            push!(name_parts, "$(param.label)_$(value)")
        end

        raw_name = _sanitize_config_name(join(name_parts, "__"))
        name = _unique_name(raw_name, seen_names)

        push!(configs, (name, overrides))
    end

    return configs
end

function _unique_name(raw_name::String, seen::Dict{String,Int})::String
    if !haskey(seen, raw_name)
        seen[raw_name] = 1
        return raw_name
    else
        count = seen[raw_name] + 1
        seen[raw_name] = count
        candidate = "$(raw_name)_$(count)"
        # Track suffixed name to avoid collision with an explicitly-named config
        seen[candidate] = get(seen, candidate, 0) + 1
        return candidate
    end
end

function _write_sensitivity_summary(
    output_dir::String,
    results::Vector{ExperimentResult},
    configs::Vector{Tuple{String,Dict{String,Any}}},
    config::SensitivityConfig,
)::String
    name_to_idx = Dict{String,Int}(name => i for (i, (name, _)) in enumerate(configs))

    rows = _build_summary_rows(results, name_to_idx, config)

    summary_path = joinpath(output_dir, "sensitivity_summary.csv")
    CSV.write(summary_path, rows)
    @info "Sensitivity summary written to \"$summary_path\""
    return summary_path
end

function _build_summary_rows(
    results::Vector{ExperimentResult},
    name_to_idx::Dict{String,Int},
    config::SensitivityConfig,
)
    if config.mode == "oat"
        return _oat_summary_rows(results, name_to_idx, config)
    else
        return _factorial_summary_rows(results, name_to_idx, config)
    end
end

function _oat_summary_rows(
    results::Vector{ExperimentResult},
    name_to_idx::Dict{String,Int},
    config::SensitivityConfig,
)
    config_metadata = Dict{Int,Tuple{String,String}}()
    seen_names = Dict{String,Int}()
    oat_idx = 0
    for param in config.parameters
        for value in param.values
            oat_idx += 1
            raw_name = _sanitize_config_name("$(param.label)_$(value)")
            _unique_name(raw_name, seen_names)  # simulate same naming as _generate_oat_configs
            config_metadata[oat_idx] = (param.label, string(value))
        end
    end

    rows = NamedTuple{
        (
            :config_name,
            :parameter_label,
            :parameter_value,
            :success,
            :train_time_s,
            :simulate_time_s,
            :error,
        ),
        Tuple{String,String,String,Bool,Float64,Float64,String},
    }[]

    for r in results
        idx = get(name_to_idx, r.config_name, nothing)
        label, value_repr = if idx !== nothing && haskey(config_metadata, idx)
            config_metadata[idx]
        else
            ("unknown", "unknown")
        end
        push!(
            rows,
            (
                config_name = r.config_name,
                parameter_label = label,
                parameter_value = value_repr,
                success = r.success,
                train_time_s = r.train_elapsed_seconds,
                simulate_time_s = r.simulate_elapsed_seconds,
                error = something(r.error_message, ""),
            ),
        )
    end
    return rows
end

function _factorial_summary_rows(
    results::Vector{ExperimentResult},
    name_to_idx::Dict{String,Int},
    config::SensitivityConfig,
)
    config_metadata = Dict{Int,Tuple{String,String}}()
    fact_idx = 0
    value_ranges = [param.values for param in config.parameters]
    all_labels = join([p.label for p in config.parameters], "__")

    for combo in Iterators.product(value_ranges...)
        fact_idx += 1
        all_values = join([string(v) for v in combo], "__")
        config_metadata[fact_idx] = (all_labels, all_values)
    end

    rows = NamedTuple{
        (
            :config_name,
            :parameter_label,
            :parameter_value,
            :success,
            :train_time_s,
            :simulate_time_s,
            :error,
        ),
        Tuple{String,String,String,Bool,Float64,Float64,String},
    }[]

    for r in results
        idx = get(name_to_idx, r.config_name, nothing)
        label, value_repr = if idx !== nothing && haskey(config_metadata, idx)
            config_metadata[idx]
        else
            ("unknown", "unknown")
        end
        push!(
            rows,
            (
                config_name = r.config_name,
                parameter_label = label,
                parameter_value = value_repr,
                success = r.success,
                train_time_s = r.train_elapsed_seconds,
                simulate_time_s = r.simulate_elapsed_seconds,
                error = something(r.error_message, ""),
            ),
        )
    end
    return rows
end
