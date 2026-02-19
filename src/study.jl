using .Lab
using .Inputs
using .Engines
using .Utils

import MathOptInterface as MOI

"""
    Study

Top-level container that binds a validated set of input data to a configured
engine. A `Study` is produced by [`read_study`](@ref) and is the required first
argument for all pipeline functions.

# Fields
- `inputs`: Validated `InputsData` object containing all input modules
  (system, scenarios, stochastic process, etc.) read from the study directory.
- `engine`: Configured [`Engine`](@ref) (e.g., [`SDDPEngine`](@ref)) that
  defines how the optimization problem is built, trained, and simulated.

See also: [`read_study`](@ref), [`build`](@ref), [`train`](@ref),
[`simulate`](@ref)
"""
struct Study
    inputs::InputsData
    engine::Engine
end

function Study(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_study_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_study_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_study_content!(d, e)
    valid_consistency = valid_content && __validate_study_consistency!(d, e)

    return if valid_consistency
        Study(d["inputs"], d["engine"])
    else
        nothing
    end
end

function Study(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing
    valid = valid_jsonc && __cast_study_internals_from_files!(d, e)

    return valid ? Study(d, e) : nothing
end

function __log_errors(e::CompositeException)
    has_errors = length(e) > 0
    has_errors && @info "Errors found:"
    for m in e
        @error m.msg
    end
    return has_errors
end

"""
    read_study(path) -> Study

Read, parse, and validate the study configuration rooted at `path`.

The function expects a `main.jsonc` file in `path` that describes all input
sub-modules and the engine configuration. All file references inside
`main.jsonc` are resolved relative to `path`.

Validation errors are accumulated and logged via `@error` before the function
returns. If validation fails the returned value is `nothing`.

# Arguments
- `path`: Absolute or relative path to a directory containing `main.jsonc`.

# Example
```julia
study = read_study("/path/to/my_study")
isnothing(study) && error("Study validation failed")
```

See also: [`build`](@ref), [`Study`](@ref)
"""
function read_study(path::String; e = CompositeException())::Study
    original_pwd = pwd()
    cd(path)
    study = Study("main.jsonc", e)
    cd(original_pwd)
    __log_errors(e)
    return study
end

"""
    build(study) -> Model

Build the optimization model described by `study`.

Reads all input files referenced in `study.inputs`, constructs the
`SDDP.PolicyGraph` subproblems, and applies variable scaling according to the
engine's `ScalingMode`. Returns a concrete [`Model`](@ref) subtype (e.g.,
`SDDPModel`) ready to be passed to [`train`](@ref).

# Arguments
- `study`: A [`Study`](@ref) returned by [`read_study`](@ref).

# Example
```julia
study = read_study("/path/to/my_study")
model = build(study)
```

See also: [`train`](@ref), [`simulate`](@ref)
"""
function build(study::Study)::Model
    return Lab.build(study.engine, study.inputs.files)
end

function build(study::Study, optimizer)::Model
    Base.depwarn(
        "build(study, optimizer) is deprecated. Use build(study) instead and configure " *
        "the solver via the \"solver\" key in the engine JSONC config.",
        :build,
    )
    return Lab.build(study.engine, study.inputs.files, optimizer)
end

function diagnose(study::Study, model::Model)::Bool
    return Lab.diagnose(model, study.engine)
end

"""
    train(study, model) -> PolicyTaskArtifact

Run the SDDP training loop on `model` using the policy definition in `study`.

Executes the cut-generation loop until the stopping criteria defined in
`study.engine.policy.convergence` are satisfied. Returns a
[`PolicyTaskArtifact`](@ref) (concretely `SDDPPolicyTaskArtifact`) containing
the trained policy graph and training log.

# Arguments
- `study`: A [`Study`](@ref) with a configured engine.
- `model`: A [`Model`](@ref) produced by [`build`](@ref).

# Example
```julia
study = read_study("/path/to/my_study")
model = build(study)
artifact = train(study, model)
```

See also: [`build`](@ref), [`simulate`](@ref), [`save_policy`](@ref)
"""
function train(study::Study, model::Model)::PolicyTaskArtifact
    return Lab.train(model, get_policy_definition(study.engine))
end

"""
    load_policy(study, model, path, format)

Load previously saved SDDP cuts from `path` into `model`.

Reads the cuts file written by a prior [`save_policy`](@ref) call and injects
the cut coefficients into the policy graph of `model`. This allows resuming
simulation from a pre-trained policy without re-running the training loop.

# Arguments
- `study`: The [`Study`](@ref) associated with the model.
- `model`: A [`Model`](@ref) produced by [`build`](@ref) with the same
  configuration as the original training run.
- `path`: Absolute path to the directory containing the cuts file.
- `format`: A [`TaskResultsFormat`](@ref) (e.g., [`CSVFormat`](@ref)) matching
  the format used by [`save_policy`](@ref).

# Example
```julia
study = read_study("/path/to/my_study")
model = build(study)
load_policy(study, model, "/path/to/output", CSVFormat())
artifact_sim = simulate(study, model)
```

See also: [`save_policy`](@ref), [`train`](@ref)
"""
function load_policy(
    study::Study, model::Model, path::String, format::TaskResultsFormat
)
    return Lab.load_policy(model, path, format)
end

"""
    save_policy(study, artifact, path, format)

Write the training artifact to `path` using the given output `format`.

Saves the SDDP cut coefficients and convergence trajectory. The output
directory is created if it does not exist. Existing files are overwritten.

# Arguments
- `study`: The [`Study`](@ref) that produced the artifact.
- `artifact`: A [`PolicyTaskArtifact`](@ref) from [`train`](@ref).
- `path`: Absolute path to the output directory.
- `format`: A [`TaskResultsFormat`](@ref) (e.g., [`CSVFormat`](@ref)).

# Example
```julia
save_policy(study, artifact, "/path/to/output", CSVFormat())
```

See also: [`load_policy`](@ref), [`train`](@ref)
"""
function save_policy(
    study::Study, artifact::PolicyTaskArtifact, path::String, format::TaskResultsFormat
)
    return Lab.save_policy(artifact, path, format)
end

"""
    simulate(study, model) -> SimulationTaskArtifact

Run Monte Carlo simulations on the trained `model` using the simulation
definition in `study`.

Samples the number of series defined in `study.engine.simulation`, evaluates
the trained policy at each stage/node, and returns a
[`SimulationTaskArtifact`](@ref) with the full trajectory data. The model must
have been trained with [`train`](@ref) before calling this function.

# Arguments
- `study`: A [`Study`](@ref) with a configured engine.
- `model`: A trained [`Model`](@ref).

# Example
```julia
artifact_policy = train(study, model)
artifact_sim = simulate(study, model)
```

See also: [`save_simulation`](@ref), [`train`](@ref)
"""
function simulate(study::Study, model::Model)::SimulationTaskArtifact
    return Lab.simulate(model, get_simulation_definition(study.engine))
end

"""
    save_simulation(study, artifact, path, format)

Write the simulation artifact to `path` using the given output `format`.

Produces one output file per monitored variable (e.g., `thermal_generation.csv`,
`hydro_generation.csv`, `operation_system.csv`). The output directory is
created if it does not exist.

# Arguments
- `study`: The [`Study`](@ref) that produced the artifact.
- `artifact`: A [`SimulationTaskArtifact`](@ref) from [`simulate`](@ref).
- `path`: Absolute path to the output directory.
- `format`: A [`TaskResultsFormat`](@ref) (e.g., [`CSVFormat`](@ref)).

# Example
```julia
artifact_sim = simulate(study, model)
save_simulation(study, artifact_sim, "/path/to/output", CSVFormat())
```

See also: [`simulate`](@ref), [`save_policy`](@ref)
"""
function save_simulation(
    study::Study, artifact::SimulationTaskArtifact, path::String, format::TaskResultsFormat
)
    return Lab.save_simulation(artifact, path, format, study.inputs.files)
end

"""
    debug(study, model, path)

Write subproblem MIP/LP files and optionally a deterministic equivalent to
`path`, using the debug configuration in `study.engine.debug`.

This is a diagnostics-only function. It does not modify the model and does not
perform any training or simulation. Useful for verifying the mathematical
formulation of individual subproblems before running the full pipeline.

# Arguments
- `study`: A [`Study`](@ref) with a configured [`DebugConfig`](@ref).
- `model`: A [`Model`](@ref) produced by [`build`](@ref).
- `path`: Absolute path to the output directory.

See also: [`DebugConfig`](@ref), [`build`](@ref)
"""
function debug(study::Study, model::Model, path::String)
    engine = study.engine
    return Lab.debug(model, engine, path)
end

"""
    validate(study, model) -> SimulationTaskArtifact

Run out-of-sample validation simulations using the configuration in
`study.engine.validation`.

Requires that [`train`](@ref) has been called on `model`. Samples a fresh set
of inflow scenarios from a different seed than training, simulates on the
trained policy, and returns an artifact with validation statistics. Throws an
error if no validation configuration is present in the engine.

# Arguments
- `study`: A [`Study`](@ref) with a configured [`OutOfSampleValidation`](@ref).
- `model`: A trained [`Model`](@ref).

See also: [`save_validation`](@ref), [`OutOfSampleValidation`](@ref)
"""
function validate(study::Study, model::Model)
    validation = get_validation_definition(study.engine)
    isnothing(validation) && error("No validation configuration in engine")
    return Lab.validate(model, validation, study.inputs.files)
end

"""
    save_validation(study, artifact, path, format)

Write the out-of-sample validation artifact to `path` in the given `format`.

Output files are written to the same structure as [`save_simulation`](@ref),
allowing direct comparison between in-sample and out-of-sample results.

# Arguments
- `study`: The [`Study`](@ref) that produced the artifact.
- `artifact`: A validation artifact from [`validate`](@ref).
- `path`: Absolute path to the output directory.
- `format`: A [`TaskResultsFormat`](@ref) (e.g., [`CSVFormat`](@ref)).

See also: [`validate`](@ref), [`OutOfSampleValidation`](@ref)
"""
function save_validation(
    study::Study, artifact, path::String, format::TaskResultsFormat
)
    return Lab.save_validation(artifact, path, format, study.inputs.files)
end
