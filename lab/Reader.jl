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

function read_ena(INDIR::String)::Dict{Int,Dict{Int,Vector{Float64}}}
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

"""
    read_exec()

Le um arquivo parametros de execucao do estudo `execucao.json`

Diferente das demais funcoes leitoras, `read_exec()` nao recebe argumento. Caso o julia seja 
inicializado com um argumento correspondendo ao caminho de um `execucao.json`, este sera usado; do
contrario, le no diretorio de entrada default `./data`
"""
function read_exec()::Dict{String,Any}
    EXEC_PATH = if length(ARGS) == 1
        ARGS[1]
    else
        "./data/execucao.json"
    end
    @info "Lendo arquivo de execucao $(EXEC_PATH)"
    out = JSON.parsefile(EXEC_PATH)
    return out
end

"""
    read_exec(INDIR::String)

Le um arquivo parametros de execucao do estudo `execucao.json` localizado em `INDIR`
"""
function read_exec(INDIR::String)::Dict{String,Any}
    EXEC_PATH = joinpath(INDIR, "execucao.json")
    @info "Lendo arquivo de execucao $(EXEC_PATH)"
    out = JSON.parsefile(EXEC_PATH)
    return out
end

end