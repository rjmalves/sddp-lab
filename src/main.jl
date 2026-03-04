"""
    julia_main()::Cint

PackageCompiler entry point. Parses ARGS and runs the full SDDP pipeline.

Returns `0` on success, `1` on validation failure or missing required arguments,
and `2` on any runtime error. Never throws -- all errors are caught and logged.

# Usage

```
sddp-lab [OPTIONS] <study-path>
```

See also: [`read_study`](@ref), [`build`](@ref), [`train`](@ref),
[`simulate`](@ref)
"""
function julia_main()::Cint
    args = copy(ARGS)

    if "--help" in args || "-h" in args
        _print_usage(stdout)
        return Cint(0)
    end

    if "--version" in args || "-V" in args
        println("SDDPlab v$(pkgversion(SDDPlab))")
        return Cint(0)
    end

    output_dir = nothing
    format_str = "parquet"
    positional = String[]

    i = 1
    while i <= length(args)
        if args[i] in ("--output", "-o")
            if i + 1 > length(args)
                @error "Flag $(args[i]) requires a value"
                _print_usage(stderr)
                return Cint(1)
            end
            output_dir = args[i + 1]
            i += 2
        elseif args[i] in ("--format", "-f")
            if i + 1 > length(args)
                @error "Flag $(args[i]) requires a value"
                _print_usage(stderr)
                return Cint(1)
            end
            format_str = args[i + 1]
            i += 2
        else
            push!(positional, args[i])
            i += 1
        end
    end

    if isempty(positional)
        @error "Missing required argument: <study-path>"
        _print_usage(stderr)
        return Cint(1)
    end

    if format_str != "parquet" && format_str != "csv"
        @error "Invalid format \"$(format_str)\": must be \"parquet\" or \"csv\""
        return Cint(1)
    end

    study_path = positional[1]
    output_dir = something(output_dir, joinpath(study_path, "data"))
    format = format_str == "csv" ? CSVFormat() : ParquetFormat()

    try
        study = read_study(study_path)
        if isnothing(study)
            @error "Study validation failed for path: $(study_path)"
            return Cint(1)
        end

        model = build(study)
        artifact_policy = train(study, model)
        save_policy(study, artifact_policy, output_dir, format)

        artifact_sim = simulate(study, model)
        save_simulation(study, artifact_sim, output_dir, format)

        @info "Pipeline complete" output = output_dir
        return Cint(0)
    catch e
        @error "Runtime error in pipeline" exception = (e, catch_backtrace())
        return Cint(2)
    end
end

function _print_usage(io::IO = stdout)
    println(
        io,
        """
Usage: sddp-lab [OPTIONS] <study-path>

Run the SDDPlab SDDP optimization pipeline on the study at <study-path>.

Arguments:
  <study-path>    Path to directory containing main.jsonc

Options:
  -o, --output    Output directory (default: <study-path>/data/)
  -f, --format    Output format: "parquet" (default) or "csv"
  -h, --help      Print this help message
  -V, --version   Print version information
""",
    )
    return nothing
end
