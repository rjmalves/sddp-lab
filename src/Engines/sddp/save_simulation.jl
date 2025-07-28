function save_simulation(
    artifact::SDDPSimulationTaskArtifact, path::String, format::TaskResultsFormat
)
    writer = get_writer(format)
    extension = get_extension(format)
    curdir = pwd()
    cd(path)
    __write_simulation_results(
        artifact.simulations, get_system(artifact.files), writer, extension
    )
    return cd(curdir)
end

# HELPERS -------------------------------------------------------------------------------------

function __extract_variable(data::Any, in_state::Bool = false, out_state::Bool = false)::Any
    if in_state
        return data.in
    elseif out_state
        return data.out
    else
        return data
    end
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
    for j in eachindex(indexes)
        index = indexes[j]
        internal_df = DataFrame()
        internal_df.stage = 1:length(simulations[1])
        internal_df[!, "variable_name"] = fill(name, length(simulations[1]))
        internal_df[!, index_name] = fill(index, length(simulations[1]))
        for i in eachindex(simulations)
            internal_df[!, string(i)] = [
                __extract_variable(s[variable][j], in_state, out_state) for
                s in simulations[i]
            ]
            internal_df[!, string(i)] = round.(internal_df[!, string(i)]; digits = 2)
        end
        append!(df, internal_df)
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
        "operation_lines" => [NET_EXCHANGE],
        "operation_hydros" => [
            STORED_VOLUME,
            INFLOW,
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
        NET_EXCHANGE => get_lines_entities(system),
        HYDRO_GENERATION => get_hydros_entities(system),
        STORED_VOLUME => get_hydros_entities(system),
        INFLOW => get_hydros_entities(system),
        TURBINED_FLOW => get_hydros_entities(system),
        OUTFLOW => get_hydros_entities(system),
        SPILLAGE => get_hydros_entities(system),
        WATER_VALUE => get_hydros_entities(system),
        HYDRO_GENERATION => get_hydros_entities(system),
    )

    # TODO - refactor replace
    map_variable_names_to_replace = Dict(
        STAGE_COST => "STAGE_COST", FUTURE_COST => "FUTURE_COST"
    )

    for (key, variables) in map_variable_output
        df = DataFrame()
        for variable in variables
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
        # TODO - refactor replace
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