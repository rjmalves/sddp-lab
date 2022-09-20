module Writer

using SDDP
using CSV
using JSON
using ..Config: ConfigData
using Plots
using DataFrames

export write_simulation_results, write_model_cuts, plot_simulation_results

OPERATION_FILENAME = "operacao.csv"
OPERATION_PLOTS = "operacao.html"
RAW_CUTS_FILENAME = "cortes.json"
PROCESSED_CUTS_FILENAME = "cortes.csv"
OUTDIR = "./out"

function __check_outdir()
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
    CSV.write(joinpath(OUTDIR, OPERATION_FILENAME), df_global)
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
    __check_outdir()
    jsonpath = joinpath(OUTDIR, RAW_CUTS_FILENAME)
    SDDP.write_cuts_to_file(model, jsonpath)
    jsondata = JSON.parsefile(jsonpath)
    rm(jsonpath)
    df = __process_cuts(jsondata, "earm")
    CSV.write(joinpath(OUTDIR, PROCESSED_CUTS_FILENAME), df)
    return df
end


function plot_simulation_results(simulations::Vector{Vector{Dict{Symbol,Any}}},
    cfg::ConfigData)
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
    SDDP.plot(plt, joinpath(OUTDIR, OPERATION_PLOTS), open=false)
end


function plot_model_cuts(cuts::DataFrame, cfg::ConfigData)
    # TODO - fazer iterativo por nó
    # TODO - obter numero de linhas
    n = length(cuts)
    x = collect(0:Int(cfg.uhe.earmax))

    # Computes all cuts over domain
    plotcut = [cuts[i][1] .+ cuts[i][2] * (x) for i = 1:n]
    plotcut = hcat(plotcut...)

    highest = mapslices(maximum, plotcut, dims=2)

    # Plots
    plot(x, plotcut; color="orange", linestyle=:dash, alpha=0.4, label="")
    plot!(x, highest; color="orange", label="Approximated function")
end

function plot_cuts(cuts, max_x)
    n = length(cuts)
    x = collect(0:max_x)

    # Computes all cuts over domain
    plotcut = [cuts[i][1] .+ cuts[i][2] * (x) for i = 1:n]
    plotcut = hcat(plotcut...)

    highest = mapslices(maximum, plotcut, dims=2)

    # Plots
    plot(x, plotcut; color="orange", linestyle=:dash, alpha=0.4, label="")
    plot!(x, highest; color="orange", label="Approximated function")
end


end