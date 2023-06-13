module Writer

using SDDP
using CSV
using JSON
using ..Config: ConfigData
using Plots
using DataFrames

export write_simulation_results, get_model_cuts, write_model_cuts, plot_simulation_results, plot_model_cuts

pythonplot()

function __check_outdir(OUTDIR::String)
    if !ispath(OUTDIR)
        mkpath(OUTDIR)
    end
end

function __extract_variable(data::Any,
    in_state::Bool=false,
    out_state::Bool=false)::Any
    if in_state
        return data.in
    elseif out_state
        return data.out
    else
        return data
    end
end

function __increase_dataframe!(df::DataFrame, variable::Symbol, name::String, indexes::Vector{Int64},
    index_name::String, simulations::Vector{Vector{Dict{Symbol,Any}}}, in_state::Bool=false, 
    out_state::Bool=false)

    for j in eachindex(indexes)
        index = indexes[j]
        internal_df = DataFrame()
        internal_df.estagio = 1:length(simulations[1])
        internal_df[!, "variavel"] = fill(name, length(simulations[1]))
        internal_df[!, index_name] = fill(index, length(simulations[1]))
        for i = eachindex(simulations)
            internal_df[!, string(i)] = [__extract_variable(s[variable][j], in_state, out_state)
                                            for s in simulations[i]]
            internal_df[!, string(i)] = round.(internal_df[!, string(i)]; digits=2)
        end
        append!(df, internal_df)
    end
end

function write_simulation_results(simulations::Vector{Vector{Dict{Symbol,Any}}}, cfg::ConfigData,
    OUTDIR::String)
    
    @info "Escrevendo resultados da simulação em $(OUTDIR)"
    
    __check_outdir(OUTDIR)

    # variaveis de hidro
    df_hidro = DataFrame()
    indexes = cfg.parque_uhe.order_uhes
    for variavel = [:gh, :earm, :vert, :ena, :vagua]
        if variavel == :earm
            __increase_dataframe!(df_hidro, :earm, "earm_inicial", indexes, "UHE", simulations, true, false)
            __increase_dataframe!(df_hidro, :earm, "earm_final", indexes, "UHE",  simulations, false, true)
        else
            __increase_dataframe!(df_hidro, variavel, string(variavel), indexes, "UHE", simulations)
        end
    end
    CSV.write(joinpath(OUTDIR, "operacao_hidro.csv"), df_hidro)
    
    # variaveis de termica
    df_termo = DataFrame()
    for variavel = [:gt]
        __increase_dataframe!(df_termo, variavel, string(variavel), [1], "UTE", simulations)
    end
    CSV.write(joinpath(OUTDIR, "operacao_termo.csv"), df_termo)
    
    # variaveis sistemicas
    df_sistema = DataFrame()
    for variavel = [:deficit, :cmo] # :cmo vai eventualmente ser uma variavel de barra
        __increase_dataframe!(df_sistema, variavel, string(variavel), [1], "SISTEMA", simulations)
    end
    CSV.write(joinpath(OUTDIR, "operacao_sistema.csv"), df_sistema)
end

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

function __process_cuts(cuts::Vector{Any}, state_var::String)::DataFrame
    df = DataFrame()
    for nodecuts in cuts
        node_df = __process_node_cut(nodecuts, state_var)
        append!(df, node_df)
    end
    return df
end

function get_model_cuts(model::SDDP.PolicyGraph)::DataFrame
    @info "Coletando cortes gerados"
    jsonpath = joinpath("rawcuts.json")
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    rm(jsonpath)
    state_vars = keys(jsondata[1]["single_cuts"][1]["coefficients"])
    df = DataFrame()
    for sv in state_vars
        sv_df = __process_cuts(jsondata, sv)
        append!(df, sv_df)
    end
    return df
end

function write_model_cuts(cuts::DataFrame, OUTDIR::String)
    PROCESSED_CUTS_PATH = joinpath(OUTDIR, "cortes.csv")
    @info "Escrevendo cortes em $(PROCESSED_CUTS_PATH)"
    CSV.write(PROCESSED_CUTS_PATH, cuts)
end

function plot_simulation_results(simulations::Vector{Vector{Dict{Symbol,Any}}}, cfg::ConfigData,
    OUTDIR::String)

    OPERATION_PLOTS_PATH = joinpath(OUTDIR, "operacao.html")
    @info "Plotando operação em $(OPERATION_PLOTS_PATH)"
    plt = SDDP.SpaghettiPlot(simulations)

    # parte hidro
    order_uhes = cfg.parque_uhe.order_uhes

    for i in 1:length(order_uhes)
        nome = "EAR_" * string(order_uhes[i])
        SDDP.add_spaghetti(plt; title=nome, ymin=0.0, ymax=cfg.parque_uhe.uhes[i].earmax) do data
            return data[:earm][i].out
        end
    end

    for i in 1:length(order_uhes)
        nome = "GH_" * string(order_uhes[i])
        SDDP.add_spaghetti(plt; title=nome, ymin=0.0, ymax=cfg.parque_uhe.uhes[i].ghmax) do data
            return data[:gh][i]
        end
    end

    for i in 1:length(order_uhes)
        nome = "VERT_" * string(order_uhes[i])
        SDDP.add_spaghetti(plt; title=nome, ymin=0.0) do data
            return data[:vert][i]
        end
    end

    for i in 1:length(order_uhes)
        nome = "ENA_" * string(order_uhes[i])
        SDDP.add_spaghetti(plt; title=nome, ymin=0.0) do data
            return data[:ena][i]
        end
    end

    for i in 1:length(order_uhes)
        nome = "VAGUA_" * string(order_uhes[i])
        SDDP.add_spaghetti(plt; title=nome, ymin=0.0) do data
            return data[:vagua][i]
        end
    end

    # termo e sistema
    SDDP.add_spaghetti(plt; title="GT", ymin=cfg.ute.gtmin, ymax=cfg.ute.gtmax) do data
        return data[:gt]
    end
    SDDP.add_spaghetti(plt; title="DEFICIT") do data
        return data[:deficit]
    end
    SDDP.add_spaghetti(plt; title="CMO") do data
        return data[:cmo]
    end
    __check_outdir(OUTDIR)
    SDDP.plot(plt, OPERATION_PLOTS_PATH, open=false)
end

function __compute_fcf1var_value(x::Vector{Float64}, s::String, cuts::DataFrame)
    cuts_stage = cuts[cuts.estagio.==s, :]
    n = size(cuts_stage)[1]
    plotcut = [cuts_stage.intercept[i] .+
                cuts_stage.coeficiente[i] * (x) for i = 1:n]
    plotcut = hcat(plotcut...)
    highest = mapslices(maximum, plotcut, dims=2)

    return highest, plotcut
end

function plot_model_cuts_1var(cuts::DataFrame, cfg::ConfigData, CUTDIR::String)
    stages = unique(cuts.estagio)
    x = collect(Float64, 0:Int(cfg.parque_uhe.uhes[1].earmax))
    for s in stages
        highest, plotcut = __compute_fcf1var_value(x, s, cuts)     
        plot(x, plotcut; ylim=(0.0, maximum(plotcut)), color="orange", dpi = 300,
            linestyle=:dash, alpha=0.4, label="")
        plot!(x, highest; color="orange", label="FCF Aproximada")
        savefig(joinpath(CUTDIR, string("estagio-", s, ".png")))
    end
end

function plot_model_cuts(cuts::DataFrame, cfg::ConfigData, OUTDIR::String)
    CUTDIR = joinpath(OUTDIR, "plotcortes")
    __check_outdir(CUTDIR)
    @info "Plotando cortes em $(CUTDIR)"
    n_uhes = cfg.parque_uhe.n_uhes
    if n_uhes == 1
        plot_model_cuts_1var(cuts, cfg, CUTDIR)
    elseif n_uhes == 2
        @error "ainda nao implementado"
    elseif n_uhes > 2
        @error "nao e possivel realizar plots para mais de duas UHEs no sistema"
    end
end

end