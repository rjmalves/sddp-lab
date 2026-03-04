using CSV

"""
    run_experiment(config_path) -> Vector{ExperimentResult}

Read the experiment configuration at `config_path`, then execute the full
`build -> train -> simulate -> save` pipeline for each named configuration.

Each configuration applies engine-level overrides on top of the base study's
`engine.params` via a deep merge. Results are written to
`<output_dir>/<config_name>/`. A summary file `experiment_summary.csv` is
written to `<output_dir>/` when the function returns.

Failures in individual configurations are caught and recorded; the runner
always continues to the next configuration. The function returns after all
configurations have been attempted.

# Example

```julia
results = run_experiment("/path/to/experiment.jsonc")
for r in results
    println(r.config_name, ": ", r.success ? "ok" : r.error_message)
end
```
"""
function run_experiment(config_path::String)::Vector{ExperimentResult}
    config = read_experiment_config(config_path)

    _prepare_output_dir(config.output_dir, config.overwrite)

    results = ExperimentResult[]
    for (config_name, overrides) in config.configurations
        @info "Running configuration: $config_name"
        result = _run_single_config(
            config.base_study_path, config_name, overrides, config.output_dir
        )
        push!(results, result)
        if result.success
            @info "Configuration \"$config_name\" completed" train_s =
                result.train_elapsed_seconds simulate_s = result.simulate_elapsed_seconds
        else
            @warn "Configuration \"$config_name\" failed" error = result.error_message
        end
    end

    _write_summary(config.output_dir, results)
    return results
end

function _prepare_output_dir(output_dir::String, overwrite::Bool)
    if isdir(output_dir)
        if !overwrite && !isempty(readdir(output_dir))
            error(
                "Output directory \"$output_dir\" is not empty. " *
                "Set \"overwrite\": true in experiment.jsonc to allow overwriting.",
            )
        end
    else
        mkpath(output_dir)
    end
end

function _run_single_config(
    base_study_path::String,
    config_name::String,
    overrides::Dict{String,Any},
    output_dir::String,
)::ExperimentResult
    config_output = abspath(joinpath(output_dir, config_name))

    train_elapsed = 0.0
    simulate_elapsed = 0.0

    original_pwd = pwd()
    try
        cd(base_study_path)
        e = CompositeException()
        base_dict = read_jsonc("main.jsonc", e)
        cd(original_pwd)

        if base_dict === nothing
            msgs = join([ex.msg for ex in e], "; ")
            return ExperimentResult(
                config_name,
                config_output,
                0.0,
                0.0,
                false,
                "Failed to read main.jsonc: $msgs",
            )
        end

        working_dict = deepcopy(base_dict)

        engine_section = get(working_dict, "engine", nothing)
        if !(engine_section isa Dict)
            return ExperimentResult(
                config_name,
                config_output,
                0.0,
                0.0,
                false,
                "Base study \"engine\" key is missing or not a Dict",
            )
        end

        engine_params = get(engine_section, "params", nothing)
        if !(engine_params isa Dict)
            return ExperimentResult(
                config_name,
                config_output,
                0.0,
                0.0,
                false,
                "Base study \"engine.params\" key is missing or not a Dict",
            )
        end

        merged_params = deep_merge(
            convert(Dict{String,Any}, engine_params), convert(Dict{String,Any}, overrides)
        )
        working_dict["engine"]["params"] = merged_params

        # Snapshot merged params before Study construction (which may mutate working_dict)
        metadata_config = deepcopy(merged_params)

        # InputsData reads files relative to base_study_path; use invokelatest for current world age
        e2 = CompositeException()
        cd(base_study_path)
        study = Base.invokelatest(Study, working_dict, e2)
        cd(original_pwd)

        if study === nothing
            msgs = join([string(ex) for ex in e2], "; ")
            return ExperimentResult(
                config_name,
                config_output,
                0.0,
                0.0,
                false,
                "Study construction failed: $msgs",
            )
        end

        # Use invokelatest so solver constructors (e.g. HiGHS.Optimizer) resolve at current world age
        model = Base.invokelatest(build, study)

        train_elapsed = @elapsed artifact_policy = Base.invokelatest(train, study, model)
        simulate_elapsed = @elapsed artifact_sim = Base.invokelatest(simulate, study, model)

        mkpath(config_output)
        Base.invokelatest(save_simulation, study, artifact_sim, config_output, CSVFormat())
        Base.invokelatest(save_policy, study, artifact_policy, config_output, CSVFormat())

        # Metadata write failures are non-fatal
        try
            env = Base.invokelatest(capture_environment)
            seeds = _extract_seeds(study)
            Base.invokelatest(
                write_run_metadata,
                output_dir,
                config_name,
                metadata_config,
                env;
                seeds = seeds,
            )
        catch ex
            @warn "Failed to write run metadata" config_name exception = (
                ex, catch_backtrace()
            )
        end

        return ExperimentResult(
            config_name, config_output, train_elapsed, simulate_elapsed, true, nothing
        )

    catch ex
        cd(original_pwd)  # always restore
        msg = sprint(showerror, ex)
        return ExperimentResult(
            config_name, config_output, train_elapsed, simulate_elapsed, false, msg
        )
    end
end

function _extract_seeds(study)::Dict{String,Any}
    seeds = Dict{String,Any}()
    try
        scenarios = Scenarios.get_scenarios(study.inputs.files)
        seeds["saa_seed"] = scenarios.seed
    catch
    end
    try
        validation = study.engine.validation
        seeds["validation_seed"] = isnothing(validation) ? nothing : validation.seed
    catch
    end
    return seeds
end

function _write_summary(output_dir::String, results::Vector{ExperimentResult})
    rows = [
        (
            config_name = r.config_name,
            success = r.success,
            train_time_s = r.train_elapsed_seconds,
            simulate_time_s = r.simulate_elapsed_seconds,
            error = something(r.error_message, ""),
        ) for r in results
    ]

    summary_path = joinpath(output_dir, "experiment_summary.csv")
    CSV.write(summary_path, rows)
    @info "Experiment summary written to \"$summary_path\""
    return summary_path
end
