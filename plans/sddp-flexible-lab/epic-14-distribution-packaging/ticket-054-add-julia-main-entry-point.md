# ticket-054 Add julia_main Entry Point with CLI Argument Parsing

## Context

### Background

PackageCompiler's `create_app` requires a `julia_main()::Cint` function in the main module as the application entry point. SDDPlab's current entry point is `read_study(path)` which returns a `Study` object, followed by `build()`, `train()`, `simulate()` called in sequence. This ticket adds a `julia_main()::Cint` function that parses CLI arguments, runs the full pipeline, and returns appropriate exit codes. This enables both `create_app` distribution and direct CLI invocation via `julia -e 'using SDDPlab; SDDPlab.julia_main()'`.

### Relation to Epic

This is the first ticket in Epic 14 (Distribution & Packaging). It provides the entry point that `create_app` (ticket-055) will use.

### Current State

- The full pipeline is in `src/study.jl`: `read_study(path)` -> `Study` -> `build(study)` -> `train(study, model)` -> `simulate(study, model)` with `save_policy` and `save_simulation` for output
- The module is `SDDPlab` (lowercase 'l') at `src/SDDPlab.jl`
- There is no `julia_main` function and no CLI argument parsing
- The existing `read_study` does `cd(path)` internally, runs the pipeline, then `cd(original_pwd)` back
- Output format is controlled by `TaskResultsFormat` (CSVFormat, ParquetFormat)
- The default output format used in examples is ParquetFormat

## Specification

### Requirements

1. Add a `julia_main()::Cint` function to the `SDDPlab` module
2. The function must parse `ARGS` (Julia's global command-line arguments) for:
   - Positional argument: `path` (required) -- the study directory containing `main.jsonc`
   - Optional `--output` / `-o` flag: output directory (defaults to `<path>/data/`)
   - Optional `--format` / `-f` flag: output format, one of `"parquet"` (default) or `"csv"`
   - Optional `--help` / `-h` flag: print usage and exit with code 0
   - Optional `--version` / `-V` flag: print version from `Project.toml` and exit with code 0
3. The function must execute the full pipeline: `read_study` -> `build` -> `train` -> `save_policy` -> `simulate` -> `save_simulation`
4. Return `0` on success, `1` on validation failure (read_study returns nothing), `2` on runtime error
5. All errors must be caught and logged via `@error` before returning the exit code
6. The function must be exported from the `SDDPlab` module

### Inputs/Props

- `ARGS::Vector{String}`: Julia's global CLI arguments
- Study directory path containing `main.jsonc` and data files

### Outputs/Behavior

- On success: runs full pipeline, writes output files to the output directory, returns `0`
- On `--help`: prints usage string to stdout, returns `0`
- On `--version`: prints "SDDPlab v{version}" to stdout, returns `0`
- On validation failure: prints error messages via `@error`, returns `1`
- On runtime error: prints error and backtrace via `@error`, returns `2`

### Error Handling

- Wrap the entire pipeline in `try...catch`
- Distinguish validation failures (read_study returns nothing) from runtime errors
- Always return a `Cint` -- never throw from `julia_main`

## Acceptance Criteria

- [ ] Given `src/SDDPlab.jl`, when inspected, then `julia_main` is exported and defined as `julia_main()::Cint`
- [ ] Given the 1dtoy example, when `julia --project -e 'ARGS=["example/1dtoy"]; using SDDPlab; exit(SDDPlab.julia_main())'` is run, then exit code is 0 and output files are written to `example/1dtoy/data/`
- [ ] Given no arguments, when `julia --project -e 'empty!(ARGS); using SDDPlab; exit(SDDPlab.julia_main())'` is run, then exit code is 1 and usage information is printed to stderr
- [ ] Given `--help` argument, when `julia --project -e 'ARGS=["--help"]; using SDDPlab; exit(SDDPlab.julia_main())'` is run, then usage is printed to stdout and exit code is 0
- [ ] Given `--version` argument, when `julia --project -e 'ARGS=["--version"]; using SDDPlab; exit(SDDPlab.julia_main())'` is run, then "SDDPlab v3.0.0" is printed and exit code is 0

## Implementation Guide

### Suggested Approach

1. Create a new file `/home/rogerio/git/sddp-lab/src/main.jl` with the `julia_main` implementation:

```julia
"""
    julia_main()::Cint

PackageCompiler entry point. Parses ARGS and runs the full SDDP pipeline.
"""
function julia_main()::Cint
    # Parse arguments
    args = copy(ARGS)

    # Handle --help
    if "--help" in args || "-h" in args
        _print_usage()
        return Cint(0)
    end

    # Handle --version
    if "--version" in args || "-V" in args
        println("SDDPlab v$(pkgversion(SDDPlab))")
        return Cint(0)
    end

    # Extract optional flags
    output_dir = nothing
    format_str = "parquet"
    positional = String[]

    i = 1
    while i <= length(args)
        if args[i] in ("--output", "-o")
            i + 1 > length(args) && (_print_usage(stderr); return Cint(1))
            output_dir = args[i + 1]
            i += 2
        elseif args[i] in ("--format", "-f")
            i + 1 > length(args) && (_print_usage(stderr); return Cint(1))
            format_str = args[i + 1]
            i += 2
        else
            push!(positional, args[i])
            i += 1
        end
    end

    if isempty(positional)
        _print_usage(stderr)
        return Cint(1)
    end

    study_path = positional[1]
    output_dir = something(output_dir, joinpath(study_path, "data"))
    format = format_str == "csv" ? CSVFormat() : ParquetFormat()

    try
        study = read_study(study_path)
        if isnothing(study)
            @error "Study validation failed"
            return Cint(1)
        end

        model = build(study)
        artifact_policy = train(study, model)
        save_policy(study, artifact_policy, output_dir, format)

        artifact_sim = simulate(study, model)
        save_simulation(study, artifact_sim, output_dir, format)

        @info "Pipeline complete" output=output_dir
        return Cint(0)
    catch e
        @error "Runtime error" exception=(e, catch_backtrace())
        return Cint(2)
    end
end

function _print_usage(io::IO=stdout)
    println(io, """
    Usage: sddp-lab [OPTIONS] <study-path>

    Run the SDDPlab SDDP optimization pipeline on the study at <study-path>.

    Arguments:
      <study-path>    Path to directory containing main.jsonc

    Options:
      -o, --output    Output directory (default: <study-path>/data/)
      -f, --format    Output format: "parquet" (default) or "csv"
      -h, --help      Print this help message
      -V, --version   Print version information
    """)
end
```

2. Include this file in `src/SDDPlab.jl` before the `@compile_workload` block:

   ```julia
   include("main.jl")
   ```

3. Add `julia_main` to the exports in `src/SDDPlab.jl`:

   ```julia
   export ..., julia_main
   ```

4. Note: `pkgversion(SDDPlab)` requires Julia >= 1.9 (which is guaranteed by the `julia = "1.10"` compat).

### Key Files to Create

- `/home/rogerio/git/sddp-lab/src/main.jl`

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/src/SDDPlab.jl` (add include and export)

### Patterns to Follow

- Follow the PackageCompiler documentation's `julia_main` signature exactly: `function julia_main()::Cint`
- Use the same `@error` logging pattern from `__log_errors` in `src/study.jl`
- Use `pkgversion(Module)` (Julia >= 1.9) instead of parsing Project.toml manually

### Pitfalls to Avoid

- Do NOT use `exit()` inside `julia_main` -- return Cint values instead. `create_app` handles the exit code from the return value.
- Do NOT use ArgParse.jl or other argument parsing packages -- manual parsing avoids an extra dependency and the CLI is simple enough
- Do NOT forget the `::Cint` return type annotation -- PackageCompiler requires it
- Do NOT modify `read_study` to accept CLI args -- keep it as-is and wrap it in `julia_main`
- The `pkgversion` call requires the module to be fully loaded, which it will be since `julia_main` is called at runtime not compile time

## Testing Requirements

### Unit Tests

- Test argument parsing logic: `--help`, `--version`, `--output`, `--format`, missing path, valid path

### Integration Tests

- Test full pipeline via `julia_main` on the 1dtoy example case
- Test exit codes: 0 for success, 1 for missing args, verify no unhandled exceptions

### E2E Tests

- Not applicable (E2E will be tested in ticket-055 with the actual compiled app)

## Dependencies

- **Blocked By**: ticket-052-implement-smart-precompile-workload.md (Epic 13 must be complete)
- **Blocks**: ticket-055-create-build-app-script-tarball.md

## Effort Estimate

**Points**: 3
**Confidence**: High
