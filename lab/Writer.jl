module Writer

using SDDP
using CSV
using JSON
using ..Config: ConfigData
using Plots
using DataFrames

export write_simulation_results, write_model_cuts, plot_simulation_results, plot_model_cuts

OPERATION_FILENAME = "operacao.csv"
OPERATION_PLOTS = "operacao.html"
RAW_CUTS_FILENAME = "cortes.json"
PROCESSED_CUTS_FILENAME = "cortes.csv"
OUTDIR = "./out"
CUTDIR = "cortes"
OPERATION_FILENAME_PATH = joinpath(OUTDIR, OPERATION_FILENAME)
OPERATION_PLOTS_PATH = joinpath(OUTDIR, OPERATION_PLOTS)
PROCESSED_CUTS_PATH = joinpath(OUTDIR, PROCESSED_CUTS_FILENAME)
CUTPATH = joinpath(OUTDIR, CUTDIR)

function __check_outdir()
    if !ispath(OUTDIR)
        mkpath(OUTDIR)
    end
    if !ispath(CUTPATH)
        mkpath(CUTPATH)
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

function __increase_dataframe!(df::DataFrame,
    variable::Symbol,
    name::String,
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    in_state::Bool=false,
    out_state::Bool=false)
    internal_df = DataFrame()
    internal_df.estagio = 1:length(simulations[1])
    internal_df[!, "variavel"] = fill(name, length(simulations[1]))
    for i = eachindex(simulations)
        internal_df[!, string(i)] = [__extract_variable(s[variable], in_state, out_state)
                                     for s in simulations[i]]
        internal_df[!, string(i)] = round.(internal_df[!, string(i)], digits=2)
    end
    append!(df, internal_df)
end

function write_simulation_results(simulations::Vector{Vector{Dict{Symbol,Any}}})
    @info "Escrevendo resultados da simulação em $(OPERATION_FILENAME_PATH)"
    df_global = DataFrame()
    for variavel = [:gt, :gh, :earm, :deficit, :vert, :ena]
        if (variavel == :earm)
            __increase_dataframe!(df_global, :earm, "earm_inicial", simulations, true, false)
            __increase_dataframe!(df_global, :earm, "earm_final", simulations, false, true)
        else
            __increase_dataframe!(df_global, variavel, string(variavel), simulations)
        end
    end
    __check_outdir()
    CSV.write(OPERATION_FILENAME_PATH, df_global)
end


function __process_node_cut(nodecuts::Any, state_var::String)::DataFrame
    df = DataFrame()
    node = nodecuts["node"]
    cutdata = nodecuts["single_cuts"]
    df[!, "estagio"] = fill(node, length(cutdata))
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

function write_model_cuts(model::SDDP.PolicyGraph)::DataFrame
    @info "Escrevendo cortes em $(PROCESSED_CUTS_PATH)"
    __check_outdir()
    jsonpath = joinpath(OUTDIR, RAW_CUTS_FILENAME)
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    rm(jsonpath)
    df = __process_cuts(jsondata, "earm")
    CSV.write(PROCESSED_CUTS_PATH, df)
    return df
end


function plot_simulation_results(simulations::Vector{Vector{Dict{Symbol,Any}}},
    cfg::ConfigData)
    @info "Plotando operação em $(OPERATION_PLOTS_PATH)"
    plt = SDDP.SpaghettiPlot(simulations)
    SDDP.add_spaghetti(plt; title="EARM", ymin=0, ymax=cfg.uhe.earmax) do data
        return data[:earm].out
    end
    SDDP.add_spaghetti(plt; title="GH", ymin=cfg.uhe.ghmin, ymax=cfg.uhe.ghmax) do data
        return data[:gh]
    end
    SDDP.add_spaghetti(plt; title="GT", ymin=cfg.ute.gtmin, ymax=cfg.ute.gtmax) do data
        return data[:gt]
    end
    SDDP.add_spaghetti(plt; title="DEFICIT") do data
        return data[:deficit]
    end
    SDDP.add_spaghetti(plt; title="VERTIMENTO") do data
        return data[:vert]
    end
    SDDP.add_spaghetti(plt; title="ENA") do data
        return data[:ena]
    end
    __check_outdir()
    SDDP.plot(plt, OPERATION_PLOTS_PATH, open=false)
end

function plot_model_cuts(cuts::DataFrame, cfg::ConfigData)
    @info "Plotando cortes em $(CUTPATH)"
    stages = unique(cuts.estagio)
    x = collect(0:Int(cfg.uhe.earmax))
    for s in stages
        cuts_stage = cuts[cuts.estagio.==s, :]
        n = size(cuts_stage)[1]
        plotcut = [cuts_stage.intercept[i] .+
                   cuts_stage.coeficiente[i] * (x) for i = 1:n]
        plotcut = hcat(plotcut...)
        highest = mapslices(maximum, plotcut, dims=2)
        plot(x, plotcut; color="orange", linestyle=:dash, alpha=0.4, label="")
        plot!(x, highest; color="orange", label="FCF Aproximada")
        savefig(joinpath(CUTPATH, string("estagio-", s, ".png")))
    end
end

end