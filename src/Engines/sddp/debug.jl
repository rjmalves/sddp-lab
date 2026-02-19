function _format_extension(fmt::String)::String
    fmt == "mof" && return ".mof.json"
    fmt == "lp" && return ".lp"
    fmt == "mps" && return ".mps"
    return ".mof.json"
end

function _node_id_to_string(id::Int)::String
    return string(id)
end

function _node_id_to_string(id::Tuple{Int,Int})::String
    return "$(id[1])_$(id[2])"
end

function Lab.debug(model::SDDPModel, engine::SDDPEngine, path::String)
    config = engine.debug

    if !config.write_subproblems && !config.deterministic_equivalent
        return nothing
    end

    t_start = time()

    debug_dir = joinpath(path, "debug")
    mkpath(debug_dir)

    ext = _format_extension(config.subproblem_format)
    written_files = String[]
    errors = Dict{String,Any}[]

    if config.write_subproblems
        for (node_id, node) in model.policy_graph.nodes
            if !isempty(config.subproblem_nodes) && !(node_id in config.subproblem_nodes)
                continue
            end
            filename = joinpath(debug_dir, "subproblem_$(_node_id_to_string(node_id))$ext")
            try
                SDDP.write_subproblem_to_file(node, filename; throw_error = false)
                push!(written_files, filename)
            catch ex
                @warn "Failed to write subproblem $node_id" exception =
                    (ex, catch_backtrace())
                push!(
                    errors,
                    Dict{String,Any}(
                        "node" => string(node_id),
                        "error" => sprint(showerror, ex),
                    ),
                )
            end
        end
    end

    if config.deterministic_equivalent
        try
            optimizer = create_optimizer(engine.solver)
            det_model = SDDP.deterministic_equivalent(
                model.policy_graph, optimizer; time_limit = config.det_equiv_time_limit
            )
            det_path = joinpath(debug_dir, "deterministic_equivalent$ext")
            JuMP.write_to_file(det_model, det_path)
            push!(written_files, det_path)
        catch ex
            @warn "Failed to write deterministic equivalent" exception =
                (ex, catch_backtrace())
            push!(
                errors,
                Dict{String,Any}(
                    "step" => "deterministic_equivalent",
                    "error" => sprint(showerror, ex),
                ),
            )
        end
    end

    summary = Dict{String,Any}(
        "write_subproblems" => config.write_subproblems,
        "subproblem_format" => config.subproblem_format,
        "deterministic_equivalent" => config.deterministic_equivalent,
        "det_equiv_time_limit" => config.det_equiv_time_limit,
        "subproblem_nodes_filter" => config.subproblem_nodes,
        "written_files" => written_files,
        "errors" => errors,
        "elapsed_time" => time() - t_start,
    )

    summary_path = joinpath(debug_dir, "debug_summary.json")
    open(summary_path, "w") do io
        JSON.print(io, summary, 2)
    end

    @info "Debug output written to $debug_dir ($(length(written_files)) files)"
    return nothing
end
