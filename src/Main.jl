using .Inputs
using .Tasks

function __run_tasks!(
    entrypoint::Union{Entrypoint,Nothing}, e::CompositeException
)::Vector{TaskArtifact}
    # Returns empty vector if no entrypoint is given
    entrypoint === nothing && return Vector{TaskArtifact}()

    path = get_path(entrypoint)
    files = get_files(entrypoint)
    tasks = get_tasks(files)
    artifacts = Vector{TaskArtifact}([InputsArtifact(path, files)])
    for task in tasks
        a = run_task(task, artifacts)
        a !== nothing || push!(e, AssertionError("Task $task failed"))
        push!(artifacts, a)
    end
    return artifacts
end

function __save_results(artifacts::Vector{TaskArtifact})
    for a in artifacts
        basedir = pwd()
        if should_write_results(a)
            path = get_task_output_path(a)
            isdir(path) || mkpath(path)
            cd(path)
            save_task(a)
            cd(basedir)
        end
    end
end

function __log_errors(e::CompositeException)
    has_errors = length(e) > 0
    has_errors && @info "Errors found:"
    for m in e
        @error m.msg
    end
    return has_errors
end

function main(; e = CompositeException())
    entrypoint = Entrypoint("main.jsonc", e)
    artifacts = __run_tasks!(entrypoint, e)
    return __log_errors(e) || __save_results(artifacts)
end