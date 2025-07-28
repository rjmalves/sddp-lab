using .Lab
using .Inputs
using .Engines
using .Utils

import MathOptInterface as MOI

# CLASS Study -----------------------------------------------------------------------

struct Study
    inputs::InputsData
    engine::Engine
end

function Study(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_study_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_study_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_study_content!(d, e)

    # Consistency validation
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

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_study_internals_from_files!(d, e)

    return valid ? Study(d, e) : nothing
end

# Main package functions -----------------------------------------------------------

function __log_errors(e::CompositeException)
    has_errors = length(e) > 0
    has_errors && @info "Errors found:"
    for m in e
        @error m.msg
    end
    return has_errors
end

function read_study(path::String; e = CompositeException())::Study
    original_pwd = pwd()
    cd(path)
    study = Study("main.jsonc", e)
    cd(original_pwd)
    __log_errors(e)
    return study
end

# Wrapper for engine-specific functions --------------------------------------------

function build(study::Study, optimizer)::Model
    return Lab.build(study.engine, study.inputs.files, optimizer)
end

function train(study::Study, model::Model)::PolicyTaskArtifact
    return Lab.train(model, get_policy_definition(study.engine))
end

function save_policy(
    study::Study, artifact::PolicyTaskArtifact, path::String, format::TaskResultsFormat
)
    return Lab.save_policy(artifact, path, format)
end

function simulate(study::Study, model::Model)::SimulationTaskArtifact
    return Lab.simulate(model, get_simulation_definition(study.engine))
end

function save_simulation(
    study::Study, artifact::SimulationTaskArtifact, path::String, format::TaskResultsFormat
)
    return Lab.save_simulation(artifact, path, format, study.inputs.files)
end