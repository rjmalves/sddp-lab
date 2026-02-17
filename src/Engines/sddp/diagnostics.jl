"""
    run_diagnostics(model, config) -> Bool

Evaluate LP coefficient range ratio against `warn_threshold` / `halt_threshold`.
Returns `false` (halt training) when the ratio exceeds `halt_threshold`.
No-op when `config.run_numerical_report == false`.
"""
function run_diagnostics(model::SDDP.PolicyGraph, config::DiagnosticsConfig)::Bool
    if !config.run_numerical_report
        return true
    end

    report_text = ""
    try
        io = IOBuffer()
        SDDP.numerical_stability_report(io, model; print = true, warn = true)
        report_text = String(take!(io))
    catch ex
        @warn "SDDP.numerical_stability_report failed" exception = (ex, catch_backtrace())
        return true
    end

    @info "Numerical Stability Report:\n$report_text"

    overall_min = Inf
    overall_max = 0.0

    for m in eachmatch(r"\[([0-9e\+\-\.]+),\s*([0-9e\+\-\.]+)\]", report_text)
        lo = tryparse(Float64, m.captures[1])
        hi = tryparse(Float64, m.captures[2])
        if lo !== nothing && hi !== nothing
            if lo > 0.0
                overall_min = min(overall_min, lo)
            end
            if hi > 0.0
                overall_max = max(overall_max, hi)
            end
        end
    end

    if overall_min == Inf || overall_max == 0.0
        @info "No coefficient ranges found in stability report; skipping threshold checks"
        return true
    end

    ratio = overall_max / overall_min

    if ratio > config.halt_threshold
        @error "Numerical stability: coefficient range ratio ($ratio) exceeds halt_threshold ($(config.halt_threshold)). Training will not proceed. Consider enabling AutoScaling or reformulating the model."
        return false
    end

    if ratio > config.warn_threshold
        @warn "Numerical stability: coefficient range ratio ($ratio) exceeds warn_threshold ($(config.warn_threshold)). Consider enabling AutoScaling or reformulating the model."
    end

    return true
end

function Lab.diagnose(model::SDDPModel, engine::SDDPEngine)::Bool
    return run_diagnostics(model.policy_graph, engine.diagnostics)
end
