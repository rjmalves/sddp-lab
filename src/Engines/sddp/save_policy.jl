function save_policy(artifact::SDDPPolicyTaskArtifact)
    cuts = __get_model_cuts(artifact.policy)
    convergence = __get_model_convergence(artifact.policy)
    writer = get_writer(artifact.definition.results.format)
    extension = get_extension(artifact.definition.results.format)
    __write_model_cuts(cuts, writer, extension)
    return __write_model_convergence(convergence, writer, extension)
end

# HELPERS -------------------------------------------------------------------------------------

function __process_node_cut_for_intercept(nodecuts::Any)::DataFrame
    df = DataFrame()
    node = nodecuts["node"]
    cutdata = nodecuts["single_cuts"]
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
    cutdata = nodecuts["single_cuts"]
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
        if length(node["single_cuts"]) > 0
            state_vars = keys(node["single_cuts"][1]["coefficients"])
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
    # TODO - add support for multicuts
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
    df = __process_convergence(logdata)
    return df
end

function __write_model_convergence(
    convergence::DataFrame, writer::Function, extension::String
)
    PROCESSED_CUTS_PATH = POLICY_CONVERGENCE_OUTPUT_FILENAME * extension
    @info "Writing convergence data to $(PROCESSED_CUTS_PATH)"
    return writer(PROCESSED_CUTS_PATH, convergence)
end
