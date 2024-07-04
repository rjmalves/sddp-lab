
using .Inputs

function log_errors(e::CompositeException)
    has_errors = length(e) > 0
    has_errors && @info "Errors found:"
    for m in e
        @error m.msg
    end
    return has_errors
end

function main(; e = CompositeException())
    entrypoint = Entrypoint("main.jsonc", e)
    artifacts = run_tasks!(entrypoint, e)
    return log_errors(e) || save_results(artifacts)
end