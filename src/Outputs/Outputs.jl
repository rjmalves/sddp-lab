module Outputs

using SDDP: SDDP
using DataFrames
using JSON
using CSV
using Plots
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
        internal_df.estagio = 1:length(simulations[1])
        internal_df[!, "variavel"] = fill(name, length(simulations[1]))
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
    __increase_dataframe!(df, variable, name, indexes, index_name, simulations, in_state, out_state)

Acrescenta dados de uma variável da operação a um DataFrame existente.

# Arguments

  - `df::DataFrame`: DataFrame com os dados para exportação
  - `variable::Symbol`: identificador interno da variável a ser adicionada
  - `name::String`: identificador externo da variável a ser adicionada
  - `elements::Vector{String}`: elementos para os quais a variável será extraída
  - `index_name::String`: nome do índice para exportação
  - `simulations::Vector{Vector{Dict{Symbol,Any}}}`: dados das séries da simulação gerados pelo `SDDP.jl`
  - `in_state::Bool`: se a extração é do estado inicial
  - `out_state::Bool`: se a extração é do estado final
"""
function __increase_dataframe!(
    df::DataFrame,
    variable::Symbol,
    name::String,
    elements::Vector{String},
    index_name::String,
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    in_state::Bool = false,
    out_state::Bool = false,
)
    for j in 1:length(elements)
        element = elements[j]
        internal_df = DataFrame()
        internal_df.estagio = 1:length(simulations[1])
        internal_df[!, "variavel"] = fill(name, length(simulations[1]))
        internal_df[!, index_name] = fill(element, length(simulations[1]))
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
  - `cfg::Configuration`: configuração de entrada para validação do número de elementos
  - `OUTDIR::String`: diretório de saída para escrita dos dados
"""
function write_simulation_results(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, cfg::Configuration
)
    @info "Escrevendo resultados da simulação"

    # variaveis de hidro
    df_hidro = DataFrame()
    names = map(u -> u.name, cfg.hydros.entities)
    for variavel in [:gh, :earm, :vert, :ena, :vagua]
        if variavel == :earm
            __increase_dataframe!(
                df_hidro, :earm, "earm_inicial", names, "UHE", simulations, true, false
            )
            __increase_dataframe!(
                df_hidro, :earm, "earm_final", names, "UHE", simulations, false, true
            )
        else
            __increase_dataframe!(
                df_hidro, variavel, string(variavel), names, "UHE", simulations
            )
        end
    end
    CSV.write("operacao_hidro.csv", df_hidro)

    # variaveis de termica
    df_termo = DataFrame()
    n_thermals = length(cfg.thermals.entities)
    for variavel in [:gt]
        __increase_dataframe!(
            df_termo, variavel, string(variavel), [n_thermals], "UTE", simulations
        )
    end
    CSV.write("operacao_termo.csv", df_termo)

    # variaveis sistemicas
    df_sistema = DataFrame()
    for variavel in [:deficit, :cmo, :stage_objective, :bellman_term, :custo_total] # :cmo vai eventualmente ser uma variavel de barra
        if variavel == :stage_objective
            __increase_dataframe!(
                df_sistema, variavel, "custo_presente", [1], "SISTEMA", simulations
            )
        elseif variavel == :bellman_term
            __increase_dataframe!(
                df_sistema, variavel, "custo_futuro", [1], "SISTEMA", simulations
            )
        else
            __increase_dataframe!(
                df_sistema, variavel, string(variavel), [1], "SISTEMA", simulations
            )
        end
    end
    return CSV.write("operacao_sistema.csv", df_sistema)
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
    df[!, "estagio"] = fill(node, length(cutdata))
    df[!, "statevar"] = fill(state_var, length(cutdata))
    df[!, "estado"] = [s["state"][state_var] for s in cutdata]
    df[!, "coeficiente"] = [s["coefficients"][state_var] for s in cutdata]
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
    return df
end

"""
    get_model_cuts(model)

Extrai os cortes gerados pelo modelo no formato de um `DataFrame`.

# Arguments

  - `model::SDDP.PolicyGraph`: modelo no formato do `SDDP.jl`
"""
function get_model_cuts(model::SDDP.PolicyGraph)::DataFrame
    @info "Coletando cortes gerados"
    jsonpath = joinpath(tempdir(), "rawcuts.json")
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    state_vars = keys(jsondata[1]["single_cuts"][1]["coefficients"])
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
function write_model_cuts(cuts::DataFrame)
    PROCESSED_CUTS_PATH = "cortes.csv"
    @info "Escrevendo cortes em $(PROCESSED_CUTS_PATH)"
    return CSV.write(PROCESSED_CUTS_PATH, cuts)
end

"""
    plot_simulation_results(cuts, cfg, OUTDIR)

Gera visualizações para as variáveis da operação calculadas durante a simulação final.

# Arguments

  - `simulations::Vector{Vector{Dict{Symbol,Any}}}`: dados da operação na simulação do `SDDP.jl`
  - `cfg::Configuration`: configuração de entrada para extração dos elementos do estudo
  - `OUTDIR::String`: diretório de saída para os plots
"""
function plot_simulation_results(
    simulations::Vector{Vector{Dict{Symbol,Any}}}, cfg::Configuration
)
    OPERATION_PLOTS_PATH = "operacao.html"
    @info "Plotando operação em $(OPERATION_PLOTS_PATH)"
    plt = SDDP.SpaghettiPlot(simulations)

    # parte hidro
    n_hydros = length(cfg.hydros)
    indexes = collect(Int64, 1:(n_hydros))

    for i in indexes
        name = "EAR_" * string(cfg.hydros.entities[i].name)
        SDDP.add_spaghetti(
            plt; title = name, ymin = 0.0, ymax = cfg.hydros.entities[i].max_storage
        ) do data
            return data[:earm][i].out
        end
    end

    for i in indexes
        name = "GH_" * string(cfg.hydros.entities[i].name)
        SDDP.add_spaghetti(
            plt; title = name, ymin = 0.0, ymax = cfg.hydros.entities[i].max_generation
        ) do data
            return data[:gh][i]
        end
    end

    for i in indexes
        name = "VERT_" * string(cfg.hydros.entities[i].name)
        SDDP.add_spaghetti(plt; title = name, ymin = 0.0) do data
            return data[:vert][i]
        end
    end

    for i in indexes
        name = "ENA_" * string(cfg.hydros.entities[i].name)
        SDDP.add_spaghetti(plt; title = name, ymin = 0.0) do data
            return data[:ena][i]
        end
    end

    for i in indexes
        name = "VAGUA_" * string(cfg.hydros.entities[i].name)
        SDDP.add_spaghetti(plt; title = name, ymin = 0.0) do data
            return data[:vagua][i]
        end
    end

    # termo
    n_thermals = length(cfg.thermals)
    indexes = collect(Int64, 1:(n_thermals))

    for i in indexes
        name = "GT_" * string(cfg.thermals.entities[i].name)
        ymin = cfg.thermals.entities[i].min_generation
        ymax = cfg.thermals.entities[i].max_generation
        SDDP.add_spaghetti(plt; title = name, ymin = ymin, ymax = ymax) do data
            return data[:gt][i]
        end
    end

    # barras
    n_buses = length(cfg.buses)
    indexes = collect(Int64, 1:(n_buses))

    for i in indexes
        name = "DEFICIT_" * string(cfg.buses.entities[i].name)
        SDDP.add_spaghetti(plt; title = name) do data
            return data[:deficit][i]
        end
    end

    for i in indexes
        name = "CMO_" * string(cfg.buses.entities[i].name)
        SDDP.add_spaghetti(plt; title = name) do data
            return data[:cmo][i]
        end
    end

    return SDDP.plot(plt, OPERATION_PLOTS_PATH; open = false)
end

"""
    __compute_fcf1var_value(x, s, cuts)

Realiza amostragem dos cortes para visualização da FCF de uma variável de estado,

# Arguments

  - `x::Vector{Float64}`: vetor de valores para amostragem dos cortes
  - `s::String`: estágio para visualização dos cortes
  - `cuts::DataFrame`: dados dos cortes do `SDDP.jl` processados
"""
function __compute_fcf1var_value(x::Vector{Float64}, s::String, cuts::DataFrame)
    cuts_stage = cuts[cuts.estagio .== s, :]
    n = size(cuts_stage)[1]
    plotcut = [
        cuts_stage.intercept[i] .+ cuts_stage.coeficiente[i] * (x .- cuts_stage.estado[i])
        for i in 1:n
    ]
    plotcut = hcat(plotcut...)
    highest = mapslices(maximum, plotcut; dims = 2)

    return highest, plotcut
end

function __compute_fcf1var_value_new(x::Vector{Float64}, s::String, cuts::DataFrame)
    min_x = minimum(x)
    max_x = maximum(x)

    cuts_stage = cuts[cuts.estagio .== s, :]
    plotcut = [
        [
            c.intercept + c.coeficiente * (min_x - c.estado),
            c.intercept + c.coeficiente * (max_x - c.estado),
        ] for c in eachrow(cuts_stage)
    ]
    plotcut = hcat(plotcut...)

    highest, idxs = findmax(
        cuts_stage.intercept .+ cuts_stage.coeficiente .* (x' .- cuts_stage.estado);
        dims = 1,
    )
    watervalue = cuts_stage.coeficiente[[myidx.I[1] for myidx in idxs]]
    return highest[:], plotcut, watervalue[:]
end

"""
    plot_model_cuts_1var(cuts, cfg, OUTDIR)

Gera visualizações para os cortes produzidos pelo modelo no caso de uma
única variável de estado.

# Arguments

  - `cuts::DataFrame`: dados dos cortes do `SDDP.jl` processados
  - `cfg::Configuration`: configuração de entrada para validação do número de elementos
  - `OUTDIR::String`: diretório de saída para os plots
"""
function plot_model_cuts_1var(cuts::DataFrame, cfg::Configuration, CUTDIR::String)
    stages = unique(cuts.estagio)
    earmax = cfg.hydros.entities[1].max_storage
    x = collect(Float64, 0:Int(earmax))
    for s in stages
        highest, plotcut, watervalue = __compute_fcf1var_value_new(x, s, cuts)
        plot(
            [minimum(x), maximum(x)],
            plotcut;
            ylim = (0.0, maximum(plotcut)),
            color = "orange",
            dpi = 300,
            linestyle = :dash,
            alpha = 0.4,
            label = "",
        )
        plot!(x, highest; color = "orange", label = "FCF Aproximada")
        savefig(joinpath(CUTDIR, string("estagio-", s, ".png")))
        plot(x, watervalue; color = "blue", label = "Valor da água")
        savefig(joinpath(CUTDIR, string("estagio-", s, "-water.png")))
    end
end

"""
    plot_model_cuts(cuts, cfg, OUTDIR)

Gera visualizações para os cortes produzidos pelo modelo.

# Arguments

  - `cuts::DataFrame`: dados dos cortes do `SDDP.jl` processados
  - `cfg::Configuration`: configuração de entrada para validação do número de elementos
  - `OUTDIR::String`: diretório de saída para os plots
"""
function plot_model_cuts(cuts::DataFrame, cfg::Configuration)
    CUTDIR = joinpath(pwd(), "plotcortes")
    __check_outdir(CUTDIR)
    @info "Plotando cortes em $(CUTDIR)"
    n_hydros = length(cfg.hydros)
    if n_hydros == 1
        plot_model_cuts_1var(cuts, cfg, CUTDIR)
    elseif n_hydros == 2
        @error "ainda nao implementado"
    elseif n_hydros > 2
        @error "nao e possivel realizar plots para mais de duas UHEs no sistema"
    end
end

export write_simulation_results,
    get_model_cuts,
    write_model_cuts,
    plot_simulation_results,
    plot_model_cuts,
    plot_model_cuts_1var

end