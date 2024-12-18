using .Inputs
using .Tasks

function __run_tasks!(entrypoint::Union{Entrypoint,Nothing}, e::CompositeException)
    # Returns empty vector if no entrypoint is given
    entrypoint === nothing && return Vector{TaskArtifact}()

    path = get_path(entrypoint)
    files = get_files(entrypoint)
    optimizer = get_optimizer(entrypoint)
    tasks = get_tasks(files)
    artifacts = Vector{TaskArtifact}([InputsArtifact(path, files, optimizer)])
    for task in tasks
        a = run_task(task, artifacts, e)
        push!(artifacts, a)
        a !== nothing || push!(e, AssertionError("Task $task failed"))
        a === nothing || __save_results(a)
    end
    return artifacts
end

function __save_results(a::TaskArtifact)
    basedir = pwd()
    if should_write_results(a)
        path = get_task_output_path(a)
        isdir(path) || mkpath(path)
        cd(path)
        save_task(a)
        cd(basedir)
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

function main(data_dir, optimizer; e = CompositeException())
    original_pwd = pwd()
    cd(data_dir)
    entrypoint = Entrypoint("main.jsonc", optimizer, e)
    __run_tasks!(entrypoint, e)
    cd(original_pwd)
    return __log_errors(e)
end