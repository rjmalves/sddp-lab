
function exit_with_errors(e::CompositeException)
    @info "Errors found:"
    for m in e
        @error m.msg
    end
    return exit(1)
end

# TODO - break function in reading - running - exporting

function main()
    e = CompositeException()
    # Inputs reading
    d = read_validate_entrypoint!("main.jsonc", e)
    d !== nothing || exit_with_errors(e)
    inputs = read_validate_inputs!(d["inputs"], e)
    outputs = read_validate_outputs!(d["outputs"], e)
    length(e) == 0 || exit_with_errors(e)
    tasks = read_validate_tasks!(d["tasks"], inputs, e)
    tasks !== nothing || exit_with_errors(e)
    # Running tasks
    artifacts = run_tasks!(tasks, e)
    # Output exporting
    return write_outputs(outputs, artifacts, e)
end