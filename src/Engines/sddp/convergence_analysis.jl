function _simple_linear_slope(x::AbstractVector, y::AbstractVector)::Float64
    n = length(x)
    if n < 2 || length(y) != n
        return NaN
    end
    x_mean = sum(x) / n
    y_mean = sum(y) / n
    numerator = 0.0
    denominator = 0.0
    for i in 1:n
        dx = x[i] - x_mean
        numerator += dx * (y[i] - y_mean)
        denominator += dx * dx
    end
    return denominator == 0.0 ? NaN : numerator / denominator
end

"""
    compute_gap_trajectory(training_log) -> DataFrame

Compute the absolute and relative optimality gap at each logged training
iteration.

The gap is defined as `simulation_value - bound`. The relative gap is
`gap_absolute / |bound|`. Returns `NaN` for iterations where the bound is zero.

# Arguments
- `training_log`: A [`TrainingLog`](@ref) from a completed training run.

# Example
```julia
artifact = train(study, model)
df = compute_gap_trajectory(artifact.training_log)
```

See also: [`compute_convergence_rate`](@ref), [`generate_convergence_report`](@ref)
"""
function compute_gap_trajectory(training_log::TrainingLog)::DataFrame
    n = length(training_log.iterations)
    df = DataFrame(
        iteration = Vector{Int}(undef, n),
        bound = Vector{Float64}(undef, n),
        simulation_value = Vector{Float64}(undef, n),
        gap_absolute = Vector{Float64}(undef, n),
        gap_relative = Vector{Float64}(undef, n),
    )
    for i in 1:n
        entry = training_log.iterations[i]
        gap_abs = entry.simulation_value - entry.bound
        abs_bound = abs(entry.bound)
        gap_rel = abs_bound == 0.0 ? NaN : gap_abs / abs_bound
        df[i, :iteration] = entry.iteration
        df[i, :bound] = entry.bound
        df[i, :simulation_value] = entry.simulation_value
        df[i, :gap_absolute] = gap_abs
        df[i, :gap_relative] = gap_rel
    end
    return df
end

"""
    compute_convergence_rate(training_log) -> Dict{String, Float64}

Compute convergence rate metrics from a completed training run.

Returns a dictionary with the following keys:
- `"bound_improvement_rate"`: Mean per-iteration improvement in the lower bound
  over the second half of training.
- `"gap_reduction_rate"`: Slope of `log(relative_gap)` vs iteration (negative =
  converging).
- `"total_time_seconds"`: Total wall-clock training time.
- `"time_per_iteration_mean"`: Mean seconds per iteration.
- `"time_per_iteration_std"`: Standard deviation of per-iteration time.
- `"iterations_total"`: Total number of iterations.
- `"final_bound"`: Lower bound at the last iteration.
- `"final_simulation_value"`: Simulated cost at the last iteration.
- `"final_gap_relative"`: Relative gap at the last iteration.

# Arguments
- `training_log`: A [`TrainingLog`](@ref) from a completed training run.

# Example
```julia
rates = compute_convergence_rate(artifact.training_log)
println("Final gap: ", rates["final_gap_relative"])
```

See also: [`compute_gap_trajectory`](@ref), [`detect_bound_stationarity`](@ref)
"""
function compute_convergence_rate(training_log::TrainingLog)::Dict{String,Float64}
    n = length(training_log.iterations)
    result = Dict{String,Float64}()

    if n == 0
        return Dict{String,Float64}(
            "bound_improvement_rate" => NaN,
            "gap_reduction_rate" => NaN,
            "total_time_seconds" => 0.0,
            "time_per_iteration_mean" => NaN,
            "time_per_iteration_std" => NaN,
            "iterations_total" => 0.0,
            "final_bound" => NaN,
            "final_simulation_value" => NaN,
            "final_gap_relative" => NaN,
        )
    end

    half = max(1, div(n, 2))
    if n <= 1
        result["bound_improvement_rate"] = 0.0
    else
        improvements = Float64[]
        for k in (half + 1):n
            push!(improvements, training_log.iterations[k].bound - training_log.iterations[k - 1].bound)
        end
        result["bound_improvement_rate"] = isempty(improvements) ? 0.0 :
                                           sum(improvements) / length(improvements)
    end

    gap_trajectory = compute_gap_trajectory(training_log)
    valid_mask = .!isnan.(gap_trajectory.gap_relative) .& (gap_trajectory.gap_relative .> 0)
    valid_iters = gap_trajectory.iteration[valid_mask]
    valid_log_gaps = Base.log.(gap_trajectory.gap_relative[valid_mask])
    result["gap_reduction_rate"] = _simple_linear_slope(
        Float64.(valid_iters), valid_log_gaps
    )

    times = [entry.time for entry in training_log.iterations]
    if n >= 2
        iter_times = diff(times)
    else
        iter_times = times
    end
    result["total_time_seconds"] = times[end]
    result["time_per_iteration_mean"] = isempty(iter_times) ? NaN :
                                        sum(iter_times) / length(iter_times)
    if length(iter_times) < 2
        result["time_per_iteration_std"] = NaN
    else
        mean_t = result["time_per_iteration_mean"]
        result["time_per_iteration_std"] = sqrt(
            sum((t - mean_t)^2 for t in iter_times) / (length(iter_times) - 1)
        )
    end

    result["iterations_total"] = Float64(n)
    last_entry = training_log.iterations[end]
    result["final_bound"] = last_entry.bound
    result["final_simulation_value"] = last_entry.simulation_value
    abs_bound = abs(last_entry.bound)
    result["final_gap_relative"] = abs_bound == 0.0 ? NaN :
                                   (last_entry.simulation_value - last_entry.bound) / abs_bound

    return result
end

"""
    detect_bound_stationarity(training_log; window, threshold) -> Dict{String, Any}

Detect whether the SDDP lower bound has become stationary (stopped improving).

Examines the last `window` iterations and checks whether the relative range
of bound values falls below `threshold`. Returns a dictionary with:
- `"is_stationary"`: `true` if the bound is stationary.
- `"stationary_since_iteration"`: The earliest iteration where stationarity
  holds (0 if not stationary).
- `"bound_range_in_window"`: Absolute range of bound values in the window.
- `"relative_bound_range"`: Relative range (`range / |final_bound|`).

# Arguments
- `training_log`: A [`TrainingLog`](@ref) from a completed training run.
- `window`: Number of trailing iterations to examine (default: 20).
- `threshold`: Relative range threshold for declaring stationarity (default: `1e-6`).

# Example
```julia
info = detect_bound_stationarity(artifact.training_log; window=30, threshold=1e-5)
info["is_stationary"] && println("Converged at iteration ", info["stationary_since_iteration"])
```

See also: [`compute_convergence_rate`](@ref), [`generate_convergence_report`](@ref)
"""
function detect_bound_stationarity(
    training_log::TrainingLog; window::Int=20, threshold::Float64=1e-6
)::Dict{String,Any}
    n = length(training_log.iterations)
    result = Dict{String,Any}()

    if n == 0
        return Dict{String,Any}(
            "is_stationary" => false,
            "stationary_since_iteration" => 0,
            "bound_range_in_window" => NaN,
            "relative_bound_range" => NaN,
        )
    end

    w = min(window, n)
    start_idx = n - w + 1
    bounds_in_window = [training_log.iterations[i].bound for i in start_idx:n]

    bound_min = minimum(bounds_in_window)
    bound_max = maximum(bounds_in_window)
    bound_range = bound_max - bound_min
    abs_final_bound = abs(training_log.iterations[end].bound)
    relative_range = abs_final_bound == 0.0 ? (bound_range == 0.0 ? 0.0 : Inf) :
                     bound_range / abs_final_bound

    is_stationary = relative_range < threshold

    stationary_since = 0
    if is_stationary && n > 0
        final_bound = training_log.iterations[end].bound
        stationary_since = training_log.iterations[end].iteration
        for i in n:-1:1
            b = training_log.iterations[i].bound
            range_from_here = abs(final_bound - b)
            rel_range_here = abs_final_bound == 0.0 ? (range_from_here == 0.0 ? 0.0 : Inf) :
                             range_from_here / abs_final_bound
            if rel_range_here >= threshold
                break
            end
            stationary_since = training_log.iterations[i].iteration
        end
    end

    result["is_stationary"] = is_stationary
    result["stationary_since_iteration"] = stationary_since
    result["bound_range_in_window"] = bound_range
    result["relative_bound_range"] = relative_range

    return result
end

"""
    generate_convergence_report(training_log) -> Dict{String, Any}

Generate a comprehensive convergence report from a completed SDDP training run.

Combines all convergence analysis functions into a single report dict with keys:
- `"status"`: Terminal status string (e.g., `"iteration_limit"`).
- `"convergence_rate"`: Output of [`compute_convergence_rate`](@ref).
- `"bound_stationarity"`: Output of [`detect_bound_stationarity`](@ref).
- `"had_numerical_issues"`: `true` if any iteration flagged a numerical issue.
- `"numerical_issue_iterations"`: List of iterations with numerical issues.

# Arguments
- `training_log`: A [`TrainingLog`](@ref) from a completed training run.

# Example
```julia
report = generate_convergence_report(artifact.training_log)
report["had_numerical_issues"] && @warn "Numerical issues detected"
```

See also: [`compute_convergence_rate`](@ref), [`detect_bound_stationarity`](@ref),
[`compute_gap_trajectory`](@ref)
"""
function generate_convergence_report(training_log::TrainingLog)::Dict{String,Any}
    report = Dict{String,Any}()

    numerical_iters = [
        entry.iteration for entry in training_log.iterations if entry.serious_numerical_issue
    ]
    report["status"] = String(training_log.status)
    report["convergence_rate"] = compute_convergence_rate(training_log)
    report["bound_stationarity"] = detect_bound_stationarity(training_log)
    report["had_numerical_issues"] = !isempty(numerical_iters)
    report["numerical_issue_iterations"] = numerical_iters
    return report
end
