module Reader

using JSON
using CSV
using DataFrames
using Logging
using ..Config

export read_config, read_ena, read_exec

function read_config(INDIR::String)::ConfigData
    CONFIG_PATH = joinpath(INDIR, "config.json")
    @info "Lendo arquivo de configuração $(CONFIG_PATH)"
    return ConfigData(JSON.parsefile(CONFIG_PATH))
end

function read_ena(INDIR::String)::Dict{Int,Dict{Int, Vector{Float64}}}
    ENA_PATH = joinpath(INDIR, "ena.csv")
    @info "Lendo arquivo de configuração $(ENA_PATH)"
    dat_ena = CSV.read(ENA_PATH, DataFrame)
    uhes = unique(dat_ena[:, :UHE])
    
    out = Dict()
    for u in uhes
        aux = Dict((e.MES, [e.MEDIA, e.DESVIO])
                for e in CSV.File(ENA_PATH) if e.UHE == u)
        out[u] = aux
    end

    return out
end

function read_exec()::Dict{String, Any}
    EXEC_PATH = if length(ARGS) == 1 ARGS[1] else "./data/execucao.json" end
    @info "Lendo arquivo de execucao $(EXEC_PATH)"
    out = JSON.parsefile(EXEC_PATH)
    return out
end

end