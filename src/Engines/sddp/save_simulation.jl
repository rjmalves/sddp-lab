function Lab.save_simulation(
    artifact::SDDPSimulationTaskArtifact,
    path::String,
    format::TaskResultsFormat,
    files::Vector{InputModule},
)
    writer = get_writer(format)
    extension = get_extension(format)
    curdir = pwd()
    cd(path)
    simulations = _unscale_simulations(artifact.simulations, artifact.scaling)
    __write_simulation_results(simulations, get_system(files), writer, extension)
    return cd(curdir)
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
    elseif sym == TURBINED_FLOW || sym == SPILLAGE || sym == OUTFLOW || sym == INFLOW || sym == INFLOW_SLACK
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
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    config::ScalingConfig,
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
                        stage_dict[sym] = [_unscale_state_variable(v, factor) for v in value]
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

function __is_2d_variable(simulations::Vector{Vector{Dict{Symbol,Any}}}, variable::Symbol)::Bool
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

function __increase_dataframe!(
    df::DataFrame,
    variable::Symbol,
    name::String,
    indexes::Vector{Int64},
    index_name::String,
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    in_state::Bool = false,
    out_state::Bool = false,
)
    is_2d = __is_2d_variable(simulations, variable)
    num_blk = is_2d ? __get_num_blocks_from_sim(simulations, variable) : 1

    for j in eachindex(indexes)
        index = indexes[j]
        for k in 1:num_blk
            internal_df = DataFrame()
            internal_df.stage = 1:length(simulations[1])
            var_name = num_blk > 1 ? "$(name)_B$(k)" : name
            internal_df[!, "variable_name"] = fill(var_name, length(simulations[1]))
            internal_df[!, index_name] = fill(index, length(simulations[1]))
            for i in eachindex(simulations)
                if is_2d
                    internal_df[!, string(i)] = [
                        __extract_variable(s[variable][j, k], in_state, out_state) for
                        s in simulations[i]
                    ]
                else
                    internal_df[!, string(i)] = [
                        __extract_variable(s[variable][j], in_state, out_state) for
                        s in simulations[i]
                    ]
                end
                internal_df[!, string(i)] = round.(internal_df[!, string(i)]; digits = 2)
            end
            append!(df, internal_df)
        end
    end
end

function __write_simulation_results(
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    system::SystemData,
    writer::Function,
    extension::String,
)
    @info "Writing simulation results"

    entity_column = "entity_id"
    num_simulations = size(simulations)[1]

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
        HYDRO_GENERATION => get_hydros_entities(system),
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
                        in_state,
                        out_state,
                    )
                end
            else
                __increase_dataframe!(
                    df, variable, string(variable), entities_ids, entity_column, simulations
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
        sort!(df, ["stage", "variable_name", entity_column, "scenario"])

        @info "Writing $(key * extension)"
        writer(key * extension, df)
    end

    return nothing
end
