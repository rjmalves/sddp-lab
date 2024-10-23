module Outputs

using SDDP: SDDP
using DataFrames
using JSON
using CSV
using ..Core
using ..System

"""
    __check_outdir(OUTDIR)

Confere a existência do diretório de saída para os dados da execução

# Arguments

  - `OUTDIR::String`: diretório configurado para saída dos dados
"""
function __check_outdir(OUTDIR::String)
    if !ispath(OUTDIR)
        mkpath(OUTDIR)
    end
end

"""
    __extract_variable(data, in_state, out_state)

Extrai o valor numérico de uma variável, abstraindo se esta é
uma variável de estado ou decisão.

# Arguments

  - `data::Any`: variável
  - `in_state::Bool`: se a extração é do estado inicial
  - `out_state::Bool`: se a extração é do estado final
"""
function __extract_variable(data::Any, in_state::Bool = false, out_state::Bool = false)::Any
    if in_state
        return data.in
    elseif out_state
        return data.out
    else
        return data
    end
end

"""
    __increase_dataframe!(df, variable, name, indexes, index_name, simulations, in_state, out_state)

Acrescenta dados de uma variável da operação a um DataFrame existente.

# Arguments

  - `df::DataFrame`: DataFrame com os dados para exportação
  - `variable::Symbol`: identificador interno da variável a ser adicionada
  - `name::String`: identificador externo da variável a ser adicionada
  - `indexes::Vector{Int64}`: índices internos dos elementos para os quais a variável será extraída
  - `index_name::String`: nome do índice para exportação
  - `simulations::Vector{Vector{Dict{Symbol,Any}}}`: dados das séries da simulação gerados pelo `SDDP.jl`
  - `in_state::Bool`: se a extração é do estado inicial
  - `out_state::Bool`: se a extração é do estado final
"""
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

"""
    write_simulation_results(simulations, OUTDIR)

Exporta os dados de saídas da simulação final do modelo.

# Arguments

  - `simulations::Vector{Vector{Dict{Symbol,Any}}}`: dados das séries da simulação gerados pelo `SDDP.jl`
  - `system::SystemData`: configuração de entrada do sistema para validação do número de elementos
  - `OUTDIR::String`: diretório de saída para escrita dos dados
"""
function write_simulation_results(
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
        "operation_system" => [STAGE_COST, FUTURE_COST, TOTAL_COST],
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
        sort!(df, ["stage", "variable_name", entity_column, "scenario"])

        @info "Writing $(key * extension)"
        writer(key * extension, df)
    end

    return nothing
end

"""
    __process_node_cut(nodecuts, state_var)

Gera um `DataFrame` com dados dos cortes de um nó.

# Arguments

  - `nodecuts::Any`: dados dos cortes de um nó, gerados pelo `SDDP.jl`
  - `state_var::String`: variável de estado a ser extraída
"""
function __process_node_cut(nodecuts::Any, state_var::String)::DataFrame
    df = DataFrame()
    node = nodecuts["node"]
    cutdata = nodecuts["single_cuts"]
    state_var_name = String.(split(state_var, "[")[1])
    state_var_id = parse(Int64, split(split(state_var, "]")[1], "[")[2])
    df[!, "stage"] = fill(parse(Int64, node), length(cutdata))
    df[!, "state_variable_name"] = fill(state_var_name, length(cutdata))
    df[!, "state_variable_id"] = fill(state_var_id, length(cutdata))
    df[!, "state"] = [s["state"][state_var] for s in cutdata]
    df[!, "coefficient"] = [s["coefficients"][state_var] for s in cutdata]
    df[!, "intercept"] = [s["intercept"] for s in cutdata]
    return df
end

"""
    __process_cuts(cuts, state_var)

Gera um `DataFrame` com dados dos cortes de um nó.

# Arguments

  - `cuts::Vector{Any}`: dados dos cortes dos nós, gerados pelo `SDDP.jl`
  - `state_var::String`: variável de estado a ser extraída
"""
function __process_cuts(cuts::Vector{Any}, state_var::String)::DataFrame
    df = DataFrame()
    for nodecuts in cuts
        node_df = __process_node_cut(nodecuts, state_var)
        append!(df, node_df)
    end
    transform!(df, ["state","coefficient","intercept"] .=> ByRow(Float64), renamecols=false)
    return sort!(df, ["stage", "state_variable_name", "state_variable_id"])
end

"""
    get_model_cuts(model)

Extrai os cortes gerados pelo modelo no formato de um `DataFrame`.

# Arguments

  - `model::SDDP.PolicyGraph`: modelo no formato do `SDDP.jl`
"""
function get_model_cuts(model::SDDP.PolicyGraph)::DataFrame
    @info "Collecting generated cuts"
    jsonpath = joinpath(tempdir(), "rawcuts.json")
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    state_vars = Vector{String}([])
    for cut in jsondata
        if length(cut["single_cuts"]) > 0
            state_vars = keys(cut["single_cuts"][1]["coefficients"])
            break
        end
    end
    state_vars = String.(state_vars)
    df = DataFrame()
    for sv in state_vars
        sv_df = __process_cuts(jsondata, sv)
        append!(df, sv_df)
    end
    return df
end

"""
    write_model_cuts(cuts, OUTDIR)

Exporta os dados dos cortes gerados pelo modelo.

# Arguments

  - `cuts::DataFrame`: dados dos cortes do `SDDP.jl` processados
  - `OUTDIR::String`: diretório de saída para escrita dos dados
"""
function write_model_cuts(cuts::DataFrame, writer::Function, extension::String)
    PROCESSED_CUTS_PATH = "cuts" * extension
    @info "Writing cuts to $(PROCESSED_CUTS_PATH)"
    return writer(PROCESSED_CUTS_PATH, cuts)
end

"""
    __process_convergence()

Gera um `DataFrame` com dados de convergência.

# Arguments

  - `cuts::Vector{Any}`: dados dos cortes dos nós, gerados pelo `SDDP.jl`
  - `state_var::String`: variável de estado a ser extraída
"""
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

"""
    get_model_convergence(model)

Extrai os dados de convergência do modelo no formato de um `DataFrame`.

# Arguments

  - `model::SDDP.PolicyGraph`: modelo no formato do `SDDP.jl`
"""
function get_model_convergence(model::SDDP.PolicyGraph)::DataFrame
    @info "Collecting convergence data"
    logpath = joinpath(tempdir(), "log.csv")
    SDDP.write_log_to_csv(model, logpath)
    logdata = CSV.read(logpath, DataFrame)
    df = __process_convergence(logdata)
    return df
end

"""
    write_model_convergence(cuts, OUTDIR)

Exporta os dados de convergência do modelo.

# Arguments

  - `convergence::DataFrame`: dados de convergência do `SDDP.jl` processados
  - `OUTDIR::String`: diretório de saída para escrita dos dados
"""
function write_model_convergence(
    convergence::DataFrame, writer::Function, extension::String
)
    PROCESSED_CUTS_PATH = "convergence" * extension
    @info "Writing convergence data to $(PROCESSED_CUTS_PATH)"
    return writer(PROCESSED_CUTS_PATH, convergence)
end

export write_simulation_results,
    get_model_cuts, write_model_cuts, get_model_convergence, write_model_convergence

end