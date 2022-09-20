module Writer

using SDDP
using CSV
using ..Config: ConfigData
using Plots
using DataFrames

export write_simulation_results, plot_simulation_results

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
    SDDP.plot(plt, "spaghetti_plot.html", open=false)

end

function __extract_variable(data::Any,
    in_state::Bool=false,
    out_state::Bool=false)::Any
    if in_state
        return data[variable].in
    elseif out_state
        return data[variable].out
    else
        return data[variable]
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
        internal_df[!, string(i)] = round.(df[!, string(i)], digits=2)
    end
    df = vcat(df, internal_df)
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
    CSV.write("operacao.csv", df_global)
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