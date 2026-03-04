function Lab.save_policy(
    artifact::SDDPPolicyTaskArtifact, path::String, format::TaskResultsFormat
)
    cuts = __get_model_cuts(artifact.policy)
    convergence = __get_model_convergence(artifact.policy)
    writer = get_writer(format)
    extension = get_extension(format)
    curdir = pwd()
    try
        cd(path)
        __write_model_cuts(cuts, writer, extension)
        __write_model_convergence(convergence, writer, extension)
        __write_training_log(artifact.training_log, writer, extension)
        __write_convergence_analysis(artifact.training_log, writer, extension)
        __write_convergence_report(artifact.training_log)
    finally
        cd(curdir)
    end
    return nothing
end

function __get_node_cutdata(nodecuts::Any)::Vector{Any}
    single = nodecuts["single_cuts"]
    multi = nodecuts["multi_cuts"]
    return isempty(single) ? multi : single
end

function __process_node_cut_for_intercept(nodecuts::Any)::DataFrame
    df = DataFrame()
    node = nodecuts["node"]
    cutdata = __get_node_cutdata(nodecuts)
    state_var_name = POLICY_CUTS_OUTPUT_INTERCEPT_NAME
    state_var_id = 0
    n_cuts = length(cutdata)
    df[!, "stage"] = fill(parse(Int64, node), n_cuts)
    df[!, "cut_index"] = 1:n_cuts
    df[!, "state_variable_name"] = fill(state_var_name, n_cuts)
    df[!, "state_variable_id"] = fill(state_var_id, n_cuts)
    df[!, "state"] = [s["intercept"] for s in cutdata]
    df[!, "coefficient"] = fill(0.0, n_cuts)
    return df
end

function __process_node_cut_for_state_var(nodecuts::Any, state_var::String)::DataFrame
    df = DataFrame()
    node = nodecuts["node"]
    cutdata = __get_node_cutdata(nodecuts)
    state_var_name = String.(split(state_var, "[")[1])
    state_var_id = parse(Int64, split(split(state_var, "]")[1], "[")[2])
    n_cuts = length(cutdata)
    df[!, "stage"] = fill(parse(Int64, node), n_cuts)
    df[!, "cut_index"] = 1:n_cuts
    df[!, "state_variable_name"] = fill(state_var_name, n_cuts)
    df[!, "state_variable_id"] = fill(state_var_id, n_cuts)
    df[!, "state"] = [s["state"][state_var] for s in cutdata]
    df[!, "coefficient"] = [s["coefficients"][state_var] for s in cutdata]
    return df
end

function __process_cuts_for_intercepts(cuts::Vector{Any})::DataFrame
    df = DataFrame()
    for nodecuts in cuts
        node_df = __process_node_cut_for_intercept(nodecuts)
        append!(df, node_df)
    end
    transform!(df, ["state", "coefficient"] .=> ByRow(Float64); renamecols = false)
    return df
end

function __process_cuts_for_state_vars(cuts::Vector{Any})::DataFrame
    state_vars = Vector{String}([])
    for node in cuts
        cutdata = __get_node_cutdata(node)
        if length(cutdata) > 0
            state_vars = keys(cutdata[1]["coefficients"])
            break
        end
    end
    state_vars = String.(state_vars)
    df = DataFrame()
    for sv in state_vars
        sv_df = DataFrame()
        for nodecuts in cuts
            node_df = __process_node_cut_for_state_var(nodecuts, sv)
            append!(sv_df, node_df)
        end
        transform!(sv_df, ["state", "coefficient"] .=> ByRow(Float64); renamecols = false)
        append!(df, sv_df)
    end
    return df
end

function __get_model_cuts(model::SDDP.PolicyGraph)::DataFrame
    @info "Collecting generated cuts"
    jsonpath = joinpath(tempdir(), "rawcuts.json")
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    intercept_df = __process_cuts_for_intercepts(jsondata)
    sv_df = __process_cuts_for_state_vars(jsondata)
    append!(intercept_df, sv_df)
    sort!(intercept_df, ["stage", "cut_index", "state_variable_name", "state_variable_id"])
    return intercept_df
end

function __write_model_cuts(cuts::DataFrame, writer::Function, extension::String)
    PROCESSED_CUTS_PATH = POLICY_CUTS_OUTPUT_FILENAME * extension
    @info "Writing cuts to $(PROCESSED_CUTS_PATH)"
    return writer(PROCESSED_CUTS_PATH, cuts)
end

function __process_convergence(logdata::DataFrame)::DataFrame
    df = logdata
    num_iterations = size(df)[1]
    map_columns_names = Dict(
        " simulation" => "simulation", " bound" => "lower_bound", " time" => "time"
    )
    rename!(df, map_columns_names)
    df[!, "upper_bound"] = fill(Inf, num_iterations)
    df[2:num_iterations, "time"] =
        df[2:num_iterations, "time"] - df[1:(num_iterations - 1), "time"]
    return select(df, ["iteration", "lower_bound", "simulation", "upper_bound", "time"])
end

function __get_model_convergence(model::SDDP.PolicyGraph)::DataFrame
    @info "Collecting convergence data"
    logpath = joinpath(tempdir(), "log.csv")
    SDDP.write_log_to_csv(model, logpath)
    logdata = CSV.read(logpath, DataFrame)
    return __process_convergence(logdata)
end

function __write_model_convergence(
    convergence::DataFrame, writer::Function, extension::String
)
    PROCESSED_CUTS_PATH = POLICY_CONVERGENCE_OUTPUT_FILENAME * extension
    @info "Writing convergence data to $(PROCESSED_CUTS_PATH)"
    return writer(PROCESSED_CUTS_PATH, convergence)
end

function __training_log_to_dataframe(training_log::TrainingLog)::DataFrame
    iters = training_log.iterations
    n = length(iters)
    return DataFrame(
        "iteration" => [e.iteration for e in iters],
        "bound" => [e.bound for e in iters],
        "simulation_value" => [e.simulation_value for e in iters],
        "time" => [e.time for e in iters],
        "total_solves" => [e.total_solves for e in iters],
        "serious_numerical_issue" => [e.serious_numerical_issue for e in iters],
        "status" => fill(String(training_log.status), n),
    )
end

function __write_training_log(
    training_log::Union{TrainingLog,Nothing}, writer::Function, extension::String
)
    if training_log === nothing
        return nothing
    end
    filepath = POLICY_TRAINING_LOG_OUTPUT_FILENAME * extension
    @info "Writing training log to $(filepath)"
    df = __training_log_to_dataframe(training_log)
    return writer(filepath, df)
end

function __write_convergence_analysis(
    training_log::Union{TrainingLog,Nothing}, writer::Function, extension::String
)
    if training_log === nothing
        return nothing
    end
    filepath = POLICY_CONVERGENCE_ANALYSIS_OUTPUT_FILENAME * extension
    @info "Writing convergence analysis to $(filepath)"
    df = compute_gap_trajectory(training_log)
    return writer(filepath, df)
end

function __write_convergence_report(training_log::Union{TrainingLog,Nothing})
    if training_log === nothing
        return nothing
    end
    filepath = POLICY_CONVERGENCE_REPORT_OUTPUT_FILENAME * ".json"
    @info "Writing convergence report to $(filepath)"
    report = generate_convergence_report(training_log)
    sanitized = __sanitize_for_json(report)
    open(filepath, "w") do io
        JSON.print(io, sanitized, 2)
    end
    return nothing
end

function __sanitize_for_json(x::Dict)
    return Dict(k => __sanitize_for_json(v) for (k, v) in x)
end

function __sanitize_for_json(x::Vector)
    return [__sanitize_for_json(v) for v in x]
end

function __sanitize_for_json(x::Float64)
    return (isnan(x) || isinf(x)) ? nothing : x
end

function __sanitize_for_json(x)
    return x
end
