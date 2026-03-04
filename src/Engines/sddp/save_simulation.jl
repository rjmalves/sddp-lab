function Lab.save_simulation(
    artifact::SDDPSimulationTaskArtifact,
    path::String,
    format::TaskResultsFormat,
    files::Vector{InputModule},
)
    writer = get_writer(format)
    extension = get_extension(format)
    curdir = pwd()
    try
        cd(path)
        simulations = _unscale_simulations(artifact.simulations, artifact.scaling)
        __write_simulation_results(simulations, get_system(files), files, writer, extension)
    finally
        cd(curdir)
    end
    return nothing
end

function _is_identity_scaling(config::ScalingConfig)::Bool
    return all(v == DEFAULT_SCALING_FACTOR for v in values(config.factors))
end

function _unscale_value(value::Real, factor::Float64)
    return value * factor
end

function _unscale_value(value::AbstractVector, factor::Float64)
    return value .* factor
end

function _unscale_value(value::AbstractMatrix, factor::Float64)
    return value .* factor
end

function _unscale_value(value, factor::Float64)
    return value
end

function _unscale_state_variable(value, factor::Float64)
    if hasproperty(value, :in) && hasproperty(value, :out)
        return (in = value.in * factor, out = value.out * factor)
    end
    return value
end

function _get_variable_unscale_factor(sym::Symbol, config::ScalingConfig)::Float64
    s_cost = get_scaling_factor(config, COST_SCALE)
    s_gen = get_scaling_factor(config, HYDRO_GENERATION)
    s_stor = get_scaling_factor(config, STORED_VOLUME)
    s_flow = get_scaling_factor(config, FLOW_SCALE)

    if sym == STORED_VOLUME
        return s_stor
    elseif sym == HYDRO_GENERATION || sym == THERMAL_GENERATION || sym == DEFICIT
        return s_gen
    elseif sym == TURBINED_FLOW ||
        sym == SPILLAGE ||
        sym == OUTFLOW ||
        sym == INFLOW ||
        sym == INFLOW_SLACK
        return s_flow
    elseif sym == DIRECT_EXCHANGE || sym == REVERSE_EXCHANGE || sym == NET_EXCHANGE
        return get_scaling_factor(config, DIRECT_EXCHANGE)
    elseif sym == NC_GENERATION || sym == NC_CURTAILMENT
        return s_gen
    elseif sym == CONTRACT_DISPATCH
        return s_gen
    elseif sym == PUMPED_FLOW
        return s_flow
    elseif sym == PUMP_POWER
        return s_gen
    elseif sym == THERMAL_GENERATION_COST
        return s_cost * s_gen
    elseif sym == MARGINAL_COST
        return s_cost
    elseif sym == WATER_VALUE
        return s_cost * s_gen / s_stor
    elseif sym == STAGE_COST || sym == FUTURE_COST || sym == TOTAL_COST
        return s_cost * s_gen
    else
        return DEFAULT_SCALING_FACTOR
    end
end

function _unscale_simulations(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, config::ScalingConfig
)::Vector{Vector{Dict{Symbol,Any}}}
    if _is_identity_scaling(config)
        return simulations
    end

    unscaled = Vector{Vector{Dict{Symbol,Any}}}(undef, length(simulations))
    for i in eachindex(simulations)
        unscaled[i] = Vector{Dict{Symbol,Any}}(undef, length(simulations[i]))
        for j in eachindex(simulations[i])
            stage_dict = copy(simulations[i][j])
            for (sym, value) in simulations[i][j]
                factor = _get_variable_unscale_factor(sym, config)
                if factor != DEFAULT_SCALING_FACTOR
                    if sym == STORED_VOLUME && value isa AbstractVector
                        stage_dict[sym] = [
                            _unscale_state_variable(v, factor) for v in value
                        ]
                    else
                        stage_dict[sym] = _unscale_value(value, factor)
                    end
                end
            end
            unscaled[i][j] = stage_dict
        end
    end

    return unscaled
end

function __extract_variable(data::Any, in_state::Bool = false, out_state::Bool = false)::Any
    if in_state
        return data.in
    elseif out_state
        return data.out
    else
        return data
    end
end

function __variable_exists_in_sim(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, variable::Symbol
)::Bool
    for sim in simulations
        for stage_dict in sim
            if haskey(stage_dict, variable)
                return true
            end
        end
    end
    return false
end

function __is_2d_variable(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, variable::Symbol
)::Bool
    for sim in simulations
        for stage_dict in sim
            if haskey(stage_dict, variable)
                return stage_dict[variable] isa AbstractMatrix
            end
        end
    end
    return false
end

function __get_num_blocks_from_sim(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, variable::Symbol
)::Int
    for sim in simulations
        for stage_dict in sim
            if haskey(stage_dict, variable)
                val = stage_dict[variable]
                if val isa AbstractMatrix
                    return size(val, 2)
                else
                    return 1
                end
            end
        end
    end
    return 1
end

function __get_num_blocks_at_stage(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, variable::Symbol, stage_idx::Int
)::Int
    for sim in simulations
        if stage_idx <= length(sim)
            stage_dict = sim[stage_idx]
            if haskey(stage_dict, variable)
                val = stage_dict[variable]
                if val isa AbstractMatrix
                    return size(val, 2)
                else
                    return 1
                end
            end
        end
    end
    return 1
end

# Build a per-stage lookup of block durations from ScenariosData.
#
# Returns a Dict{Int, Vector{Float64}} mapping stage index -> per-block duration
# vector. For stages with no explicit block config, this is [tau] where tau is
# the full stage duration in hours.
function __build_stage_block_durations(
    files::Vector{InputModule}
)::Dict{Int,Vector{Float64}}
    scenarios = get_scenarios(files)
    graph = get_graph(scenarios)
    stage_block_durations = Dict{Int,Vector{Float64}}()

    for node in graph.nodes
        stage = Int(node.stage)
        if !haskey(stage_block_durations, stage)
            tau =
                Float64(Dates.value(node.end_datetime - node.start_datetime)) / 3_600_000.0
            bc = get_block_config(scenarios, stage)
            tau_k = get_block_durations(bc, tau)
            stage_block_durations[stage] = tau_k
        end
    end

    return stage_block_durations
end

# Append rows to `df` for one variable and one entity, across all scenarios and stages.
#
# Parameters:
#   df               - DataFrame to append to (mutated in place)
#   variable         - Symbol key in the simulation Dict
#   name             - Clean variable name for the `variable_name` column (never mangled)
#   indexes          - Entity index vector (one entry per entity)
#   index_name       - Column name for the entity id column
#   simulations      - Nested simulation results [scenario][stage]
#   stage_block_durations - Dict{Int, Vector{Float64}} from __build_stage_block_durations
#   in_state         - Extract `.in` from a state variable
#   out_state        - Extract `.out` from a state variable
#
# The `block_index` column is `missing` when `num_blk == 1` (covers both truly 1D
# variables and K=1 stages with no explicit blocks) and `k::Int` when `num_blk > 1`.
# The `block_duration_hours` column is:
#   - `tau_k[k]` when `num_blk > 1` (per-block duration from BlockConfig)
#   - total stage tau (`sum(tau_k)`) when `num_blk == 1`
function __increase_dataframe!(
    df::DataFrame,
    variable::Symbol,
    name::String,
    indexes::Vector{Int64},
    index_name::String,
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    stage_block_durations::Dict{Int,Vector{Float64}},
    in_state::Bool = false,
    out_state::Bool = false,
)
    is_2d = __is_2d_variable(simulations, variable)
    num_stages = length(simulations[1])
    num_simulations = length(simulations)

    # Build a mapping from simulation step index (1-based) to graph stage number.
    # SDDP.jl records the node_index in each stage dict as :node_index. The graph
    # stage number equals __extract_stage(node_index) = Int(node_index) for integer nodes.
    # For non-Markov graphs this is just the node ID.
    # This mapping is needed because stage_block_durations is keyed by graph stage number,
    # not by the 1-based simulation step index.
    step_to_graph_stage = Dict{Int,Int}()
    for step_idx in 1:num_stages
        for sim in simulations
            if step_idx <= length(sim)
                sd = sim[step_idx]
                if haskey(sd, :node_index)
                    node_idx = sd[:node_index]
                    # For Markov (Tuple{Int,Int}) extract first element as stage
                    graph_stage = if node_idx isa Tuple
                        node_idx[1]
                    else
                        Int(node_idx)
                    end
                    step_to_graph_stage[step_idx] = graph_stage
                    break
                end
            end
        end
        # Fallback: if no :node_index found, assume step == graph stage
        if !haskey(step_to_graph_stage, step_idx)
            step_to_graph_stage[step_idx] = step_idx
        end
    end

    for j in eachindex(indexes)
        index = indexes[j]
        # Collect all (stage, block_index) rows into flat vectors, then build the DataFrame
        # once. This handles per-stage variable K correctly when K varies across stages.
        n_rows = 0
        for stage_idx in 1:num_stages
            k_s = is_2d ? __get_num_blocks_at_stage(simulations, variable, stage_idx) : 1
            n_rows += k_s
        end

        stage_col = Vector{Int}(undef, n_rows)
        var_col = Vector{String}(undef, n_rows)
        idx_col = Vector{Int}(undef, n_rows)
        block_index_col = Vector{Union{Int,Missing}}(undef, n_rows)
        block_duration_col = Vector{Float64}(undef, n_rows)
        sim_cols = [Vector{Float64}(undef, n_rows) for _ in 1:num_simulations]

        row = 1
        for stage_idx in 1:num_stages
            k_s = is_2d ? __get_num_blocks_at_stage(simulations, variable, stage_idx) : 1
            has_explicit_blocks_at_stage = k_s > 1

            # Look up block durations using the graph stage number (not the sim step index)
            graph_stage = get(step_to_graph_stage, stage_idx, stage_idx)
            tau_k = if haskey(stage_block_durations, graph_stage)
                stage_block_durations[graph_stage]
            elseif haskey(stage_block_durations, stage_idx)
                # Fallback to step index if graph stage not found
                stage_block_durations[stage_idx]
            else
                @warn "Stage $stage_idx (graph stage $graph_stage): no BlockConfig found " *
                    "in ScenariosData; setting block_duration_hours = NaN"
                Float64[NaN]
            end

            for k in 1:k_s
                stage_col[row] = stage_idx
                var_col[row] = name
                idx_col[row] = index
                block_index_col[row] = has_explicit_blocks_at_stage ? k : missing

                block_duration_col[row] = if has_explicit_blocks_at_stage
                    if k <= length(tau_k)
                        tau_k[k]
                    else
                        @warn "Stage $stage_idx: block_index $k exceeds configured block " *
                            "count $(length(tau_k))"
                        NaN
                    end
                else
                    sum(tau_k)
                end

                for i in 1:num_simulations
                    val = if is_2d
                        simulations[i][stage_idx][variable][j, k]
                    else
                        simulations[i][stage_idx][variable][j]
                    end
                    sim_cols[i][row] = round(
                        Float64(__extract_variable(val, in_state, out_state)); digits = 2
                    )
                end
                row += 1
            end
        end

        internal_df = DataFrame()
        internal_df[!, "stage"] = stage_col
        internal_df[!, "variable_name"] = var_col
        internal_df[!, index_name] = idx_col
        internal_df[!, "block_index"] = block_index_col
        internal_df[!, "block_duration_hours"] = block_duration_col
        for i in 1:num_simulations
            internal_df[!, string(i)] = sim_cols[i]
        end
        append!(df, internal_df)
    end
end

function __write_simulation_results(
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    system::SystemData,
    files::Vector{InputModule},
    writer::Function,
    extension::String,
)
    @info "Writing simulation results"

    entity_column = "entity_id"
    num_simulations = size(simulations)[1]

    # Build per-stage block duration lookup from ScenariosData
    stage_block_durations = __build_stage_block_durations(files)

    map_variable_output = Dict(
        "operation_buses" => [DEFICIT, MARGINAL_COST],
        "operation_thermals" => [THERMAL_GENERATION, THERMAL_GENERATION_COST],
        "operation_noncontrollables" => [NC_GENERATION, NC_CURTAILMENT],
        "operation_contracts" => [CONTRACT_DISPATCH],
        "operation_pumping" => [PUMPED_FLOW, PUMP_POWER],
        "operation_lines" => [NET_EXCHANGE],
        "operation_hydros" => [
            STORED_VOLUME,
            INFLOW,
            INFLOW_SLACK,
            NOISE_ADJUSTMENT_SLACK,
            TURBINED_FLOW,
            OUTFLOW,
            SPILLAGE,
            WATER_VALUE,
            HYDRO_GENERATION,
        ],
        "operation_system" =>
            [STAGE_COST, FUTURE_COST, TOTAL_COST, VERTEX_COVERAGE_DISTANCE],
    )

    map_variable_entities = Dict(
        DEFICIT => get_buses_entities(system),
        MARGINAL_COST => get_buses_entities(system),
        THERMAL_GENERATION => get_thermals_entities(system),
        THERMAL_GENERATION_COST => get_thermals_entities(system),
        NC_GENERATION => get_noncontrollables_entities(system),
        NC_CURTAILMENT => get_noncontrollables_entities(system),
        CONTRACT_DISPATCH => get_energycontracts_entities(system),
        PUMPED_FLOW => get_pumpingstations_entities(system),
        PUMP_POWER => get_pumpingstations_entities(system),
        NET_EXCHANGE => get_lines_entities(system),
        HYDRO_GENERATION => get_hydros_entities(system),
        STORED_VOLUME => get_hydros_entities(system),
        INFLOW => get_hydros_entities(system),
        INFLOW_SLACK => get_hydros_entities(system),
        NOISE_ADJUSTMENT_SLACK => get_hydros_entities(system),
        TURBINED_FLOW => get_hydros_entities(system),
        OUTFLOW => get_hydros_entities(system),
        SPILLAGE => get_hydros_entities(system),
        WATER_VALUE => get_hydros_entities(system),
    )

    for (key, variables) in map_variable_output
        df = DataFrame()
        for variable in variables
            if !__variable_exists_in_sim(simulations, variable)
                continue
            end
            if variable in keys(map_variable_entities)
                entities_ids = map(u -> u.id, map_variable_entities[variable])
            else
                entities_ids = Vector{Int64}([1])
            end
            if length(entities_ids) == 0
                break
            end
            if variable == STORED_VOLUME
                for (direction, in_state, out_state) in
                    zip(["_IN", "_OUT"], [true, false], [false, true])
                    __increase_dataframe!(
                        df,
                        variable,
                        String(variable) * direction,
                        entities_ids,
                        entity_column,
                        simulations,
                        stage_block_durations,
                        in_state,
                        out_state,
                    )
                end
            else
                __increase_dataframe!(
                    df,
                    variable,
                    string(variable),
                    entities_ids,
                    entity_column,
                    simulations,
                    stage_block_durations,
                )
            end
        end
        if size(df)[1] == 0
            continue
        end
        df = stack(df, string.(Array((1:num_simulations))))
        rename!(df, "variable" => "scenario")
        df[!, "scenario"] = parse.(Int64, df[!, "scenario"])
        df[!, "variable_name"] =
            replace.(df[!, "variable_name"], "stage_objective" => "STAGE_COST")
        df[!, "variable_name"] =
            replace.(df[!, "variable_name"], "bellman_term" => "FUTURE_COST")
        df[!, "variable_name"] =
            replace.(
                df[!, "variable_name"],
                "bellman_vertex_coverage_distance" => "VERTEX_COVERAGE_DISTANCE",
            )
        sort!(
            df,
            ["stage", "variable_name", entity_column, "block_index", "scenario"];
            lt = isless,
        )

        @info "Writing $(key * extension)"
        writer(key * extension, df)
    end

    return nothing
end
