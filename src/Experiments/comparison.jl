using CSV
using DataFrames
using Statistics

"""
    ConfigSummary

Holds per-configuration summary statistics from an experiment output directory.

# Fields
- `config_name`: Name of the configuration (same as subdirectory name).
- `statistics`: Dict of summary metrics — same keys as `_compute_validation_statistics`
  in `src/Engines/sddp/validate.jl`: `mean_cost`, `std_cost`, `ci_lower_95`,
  `ci_upper_95`, `p05_cost`, `p50_cost`, `p95_cost`, `min_cost`, `max_cost`,
  `num_simulations`.
- `train_time_s`: Wall-clock seconds spent in training (NaN when unavailable).
- `simulate_time_s`: Wall-clock seconds spent in simulation (NaN when unavailable).
- `num_scenarios`: Number of simulated scenarios found in the output file.

# Example
```julia
summary = ConfigSummary("iter3", stats_dict, 12.4, 3.1, 10)
```
"""
struct ConfigSummary
    config_name::String
    statistics::Dict{String,Float64}
    train_time_s::Float64
    simulate_time_s::Float64
    num_scenarios::Int
end

"""
    ComparisonResult

Holds the aggregated comparison across all (or a subset of) configurations in
an experiment output directory.

# Fields
- `summaries`: One `ConfigSummary` per successfully-loaded configuration.
- `output_dir`: Absolute path to the experiment output directory that was scanned.
  Config subdirectories are `joinpath(output_dir, config_name)`.

# Example
```julia
result = aggregate_experiment_results("/path/to/experiment_output")
println(length(result.summaries), " configs loaded")
```
"""
struct ComparisonResult
    summaries::Vector{ConfigSummary}
    output_dir::String
end

"""
    aggregate_experiment_results(output_dir) -> ComparisonResult

Scan all subdirectories of `output_dir`, load per-scenario total costs from
each configuration's `operation_system.csv` (or `.parquet`), compute summary
statistics, and return a `ComparisonResult`.

Timing data is read from `experiment_summary.csv` in `output_dir` when present;
if that file is absent, timing values default to `NaN`.

Configurations missing the expected output file are skipped with a `@warn`.

# Example
```julia
result = aggregate_experiment_results("/path/to/experiment_output")
for s in result.summaries
    println(s.config_name, ": mean=", s.statistics["mean_cost"])
end
```
"""
function aggregate_experiment_results(output_dir::String)::ComparisonResult
    abs_dir = abspath(output_dir)
    timing = _read_experiment_timing(abs_dir)

    summaries = ConfigSummary[]
    for entry in sort(readdir(abs_dir; join = true))
        isdir(entry) || continue
        config_name = basename(entry)

        costs = _load_total_costs(entry)
        if costs === nothing
            @warn "Skipping config \"$config_name\": no operation_system file found in \"$entry\""
            continue
        end
        if isempty(costs)
            @warn "Skipping config \"$config_name\": operation_system file has no STAGE_COST rows"
            continue
        end

        stats = _compute_comparison_statistics(costs)
        train_t, sim_t = get(timing, config_name, (NaN, NaN))

        push!(summaries, ConfigSummary(config_name, stats, train_t, sim_t, length(costs)))
    end

    return ComparisonResult(summaries, abs_dir)
end

"""
    compare_configs(output_dir, config_names) -> ComparisonResult

Aggregate only the configurations whose names appear in `config_names`.
Configs listed in `config_names` that are not found in `output_dir` are skipped
with a `@warn`.

# Example
```julia
result = compare_configs("/path/to/experiment_output", ["iter3", "iter5"])
```
"""
function compare_configs(
    output_dir::String, config_names::Vector{String}
)::ComparisonResult
    abs_dir = abspath(output_dir)
    timing = _read_experiment_timing(abs_dir)

    summaries = ConfigSummary[]
    for name in config_names
        entry = joinpath(abs_dir, name)
        if !isdir(entry)
            @warn "Skipping config \"$name\": directory not found in \"$abs_dir\""
            continue
        end

        costs = _load_total_costs(entry)
        if costs === nothing
            @warn "Skipping config \"$name\": no operation_system file found in \"$entry\""
            continue
        end
        if isempty(costs)
            @warn "Skipping config \"$name\": operation_system file has no STAGE_COST rows"
            continue
        end

        stats = _compute_comparison_statistics(costs)
        train_t, sim_t = get(timing, name, (NaN, NaN))

        push!(summaries, ConfigSummary(name, stats, train_t, sim_t, length(costs)))
    end

    return ComparisonResult(summaries, abs_dir)
end

"""
    write_comparison(result, path, format)

Write two comparison files into `path`:

1. `comparison_summary.<ext>` — wide-format table with one row per configuration.
   Columns: `config_name`, `mean_cost`, `std_cost`, `ci_lower_95`, `ci_upper_95`,
   `p05_cost`, `p50_cost`, `p95_cost`, `min_cost`, `max_cost`, `num_scenarios`,
   `train_time_s`, `simulate_time_s`.

2. `comparison_costs.<ext>` — long-format table with all per-scenario costs.
   Columns: `config_name`, `scenario`, `total_cost`.

The per-scenario cost data is read back from `result.output_dir` (the directory
that was originally scanned), so the config subdirectories must still exist.
The file extension is determined by `format` (e.g., `.csv` for `CSVFormat()`).

# Example
```julia
result = aggregate_experiment_results("/path/to/output")
write_comparison(result, "/path/to/output", CSVFormat())
```
"""
function write_comparison(
    result::ComparisonResult, path::String, format::TaskResultsFormat
)
    writer = get_writer(format)
    extension = get_extension(format)

    abs_path = abspath(path)
    mkpath(abs_path)

    _write_comparison_summary(result.summaries, abs_path, writer, extension)
    _write_comparison_costs(result.summaries, result.output_dir, abs_path, writer, extension)

    return nothing
end

function _load_total_costs(config_dir::String)::Union{Vector{Float64},Nothing}
    csv_path = joinpath(config_dir, "operation_system.csv")
    parquet_path = joinpath(config_dir, "operation_system.parquet")

    df = if isfile(csv_path)
        CSV.read(csv_path, DataFrame)
    elseif isfile(parquet_path)
        DataFrame(Parquet.read_parquet(parquet_path))
    else
        return nothing
    end

    for col in ["variable_name", "scenario", "value"]
        if !(col in names(df))
            @warn "operation_system file in \"$config_dir\" is missing column \"$col\""
            return nothing
        end
    end

    # Sum STAGE_COST (not TOTAL_COST, which includes future cost estimates and would double-count)
    stage_cost_df = filter(row -> row.variable_name == "STAGE_COST", df)
    nrow(stage_cost_df) == 0 && return Float64[]

    stage_cost_df = transform(stage_cost_df, :value => (v -> Float64.(v)) => :value)
    scenario_totals = combine(
        groupby(stage_cost_df, :scenario), :value => sum => :total_cost
    )
    sort!(scenario_totals, :scenario)

    return scenario_totals.total_cost
end

function _read_experiment_timing(output_dir::String)::Dict{String,Tuple{Float64,Float64}}
    summary_path = joinpath(output_dir, "experiment_summary.csv")
    result = Dict{String,Tuple{Float64,Float64}}()

    isfile(summary_path) || return result

    df = try
        CSV.read(summary_path, DataFrame)
    catch ex
        @warn "Could not read experiment_summary.csv from \"$output_dir\"" exception = ex
        return result
    end

    for col in ["config_name", "train_time_s", "simulate_time_s"]
        if !(col in names(df))
            @warn "experiment_summary.csv is missing column \"$col\" — timing data will be NaN"
            return result
        end
    end

    for row in eachrow(df)
        name = string(row.config_name)
        train_t = _to_float64_or_nan(row.train_time_s)
        sim_t = _to_float64_or_nan(row.simulate_time_s)
        result[name] = (train_t, sim_t)
    end

    return result
end

function _to_float64_or_nan(x)::Float64
    x === missing && return NaN
    try
        return Float64(x)
    catch
        return NaN
    end
end

function _compute_comparison_statistics(
    total_costs::Vector{Float64},
)::Dict{String,Float64}
    n = length(total_costs)
    mu = Statistics.mean(total_costs)
    sigma = n > 1 ? Statistics.std(total_costs) : 0.0
    se = n > 1 ? sigma / sqrt(n) : 0.0

    z = n >= 30 ? 1.96 : _comparison_t_quantile_95(n - 1)

    return Dict{String,Float64}(
        "mean_cost" => mu,
        "std_cost" => sigma,
        "ci_lower_95" => mu - z * se,
        "ci_upper_95" => mu + z * se,
        "p05_cost" => Statistics.quantile(total_costs, 0.05),
        "p50_cost" => Statistics.quantile(total_costs, 0.50),
        "p95_cost" => Statistics.quantile(total_costs, 0.95),
        "max_cost" => maximum(total_costs),
        "min_cost" => minimum(total_costs),
        "num_simulations" => Float64(n),
    )
end

# Identical lookup table to _t_quantile_95 in validate.jl; duplicated to avoid
# depending on SDDP engine internals.
function _comparison_t_quantile_95(df::Integer)::Float64
    if df <= 0
        return Inf
    elseif df == 1
        return 12.706
    elseif df == 2
        return 4.303
    elseif df == 3
        return 3.182
    elseif df == 4
        return 2.776
    elseif df == 5
        return 2.571
    elseif df <= 10
        table = [2.447, 2.365, 2.306, 2.262, 2.228]
        return table[df - 5]
    elseif df <= 20
        table = [2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086]
        return table[df - 10]
    elseif df <= 29
        return 2.086 - (df - 20) * (2.086 - 2.045) / 9
    else
        return 1.96
    end
end

function _write_comparison_summary(
    summaries::Vector{ConfigSummary},
    path::String,
    writer::Function,
    extension::String,
)
    rows = [
        (
            config_name = s.config_name,
            mean_cost = s.statistics["mean_cost"],
            std_cost = s.statistics["std_cost"],
            ci_lower_95 = s.statistics["ci_lower_95"],
            ci_upper_95 = s.statistics["ci_upper_95"],
            p05_cost = s.statistics["p05_cost"],
            p50_cost = s.statistics["p50_cost"],
            p95_cost = s.statistics["p95_cost"],
            min_cost = s.statistics["min_cost"],
            max_cost = s.statistics["max_cost"],
            num_scenarios = s.num_scenarios,
            train_time_s = s.train_time_s,
            simulate_time_s = s.simulate_time_s,
        ) for s in summaries
    ]

    out_path = joinpath(path, "comparison_summary" * extension)
    writer(out_path, rows)
    @info "Comparison summary written to \"$out_path\""
    return out_path
end

function _write_comparison_costs(
    summaries::Vector{ConfigSummary},
    source_dir::String,
    write_path::String,
    writer::Function,
    extension::String,
)
    rows = NamedTuple{(:config_name, :scenario, :total_cost),Tuple{String,Int,Float64}}[]

    for s in summaries
        config_dir = joinpath(source_dir, s.config_name)
        costs = _load_total_costs(config_dir)
        if costs === nothing || isempty(costs)
            @warn "comparison_costs: could not load costs for config \"$(s.config_name)\" — skipping"
            continue
        end
        for (i, c) in enumerate(costs)
            push!(rows, (config_name = s.config_name, scenario = i, total_cost = c))
        end
    end

    out_path = joinpath(write_path, "comparison_costs" * extension)
    writer(out_path, rows)
    @info "Comparison costs written to \"$out_path\""
    return out_path
end
