"""
    julia_main()::Cint

PackageCompiler entry point. Parses ARGS and runs the SDDP pipeline.

Returns `0` on success, `1` on validation failure or missing required arguments,
and `2` on any runtime error. Never throws -- all errors are caught and logged.

# Usage

```
sddp-lab [OPTIONS] <study-path>
```

# Task Selection

By default, both policy training and simulation are executed. Use `--policy-only`
or `--simulate-only` to run a single phase. When simulating without training,
the policy is loaded from disk (from `--policy-path` or the output directory).

See also: [`read_study`](@ref), [`build`](@ref), [`train`](@ref),
[`simulate`](@ref), [`load_policy`](@ref)
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
    policy_only = false
    simulate_only = false
    policy_path = nothing
    no_save_policy = false
    no_save_simulation = false
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
        elseif args[i] == "--policy-only"
            policy_only = true
            i += 1
        elseif args[i] == "--simulate-only"
            simulate_only = true
            i += 1
        elseif args[i] == "--policy-path"
            if i + 1 > length(args)
                @error "Flag --policy-path requires a value"
                _print_usage(stderr)
                return Cint(1)
            end
            policy_path = args[i + 1]
            i += 2
        elseif args[i] == "--no-save-policy"
            no_save_policy = true
            i += 1
        elseif args[i] == "--no-save-simulation"
            no_save_simulation = true
            i += 1
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

    if policy_only && simulate_only
        @error "Cannot use --policy-only and --simulate-only together"
        return Cint(1)
    end

    if format_str != "parquet" && format_str != "csv"
        @error "Invalid format \"$(format_str)\": must be \"parquet\" or \"csv\""
        return Cint(1)
    end

    study_path = positional[1]
    output_dir = something(output_dir, joinpath(study_path, "data"))
    format = format_str == "csv" ? CSVFormat() : ParquetFormat()

    # Default policy load path is the output directory
    if simulate_only && isnothing(policy_path)
        policy_path = output_dir
    end

    run_train = !simulate_only
    run_simulate = !policy_only

    try
        study = read_study(study_path)
        if isnothing(study)
            @error "Study validation failed for path: $(study_path)"
            return Cint(1)
        end

        model = build(study)

        if run_train
            artifact_policy = train(study, model)
            if !no_save_policy
                save_policy(study, artifact_policy, output_dir, format)
            end
        end

        if run_simulate
            if simulate_only
                @info "Loading policy from $(policy_path)"
                load_policy(study, model, policy_path, format)
            end
            artifact_sim = simulate(study, model)
            if !no_save_simulation
                save_simulation(study, artifact_sim, output_dir, format)
            end
        end

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
  <study-path>          Path to directory containing main.jsonc

Task selection:
  --policy-only         Train policy and exit (skip simulation)
  --simulate-only       Load policy from disk and simulate (skip training)

Policy source:
  --policy-path <dir>   Directory to load policy from (default: output dir)
                        Only used with --simulate-only

Output control:
  -o, --output <dir>    Output directory (default: <study-path>/data/)
  -f, --format <fmt>    Output format: "parquet" (default) or "csv"
  --no-save-policy      Skip saving policy artifacts after training
  --no-save-simulation  Skip saving simulation results

General:
  -h, --help            Print this help message
  -V, --version         Print version information
""",
    )
    return nothing
end
