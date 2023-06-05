module Reader

using JSON
using CSV
using Logging
using ..Config

export read_config, read_ena

CONFIG_FILENAME = "config.json"
ENA_FILENAME = "ena.csv"
INDIR = "./data"
CONFIG_PATH = joinpath(INDIR, CONFIG_FILENAME)
ENA_PATH = joinpath(INDIR, ENA_FILENAME)

function read_config()::ConfigData
    @info "Lendo arquivo de configuração $(CONFIG_PATH)"
    return ConfigData(JSON.parsefile(CONFIG_PATH))
end

function read_ena()::Dict{Int,Vector{Float64}}
    @info "Lendo arquivo de configuração $(ENA_PATH)"
    return Dict((e.MES, [e.MEDIA, e.DESVIO])
                for e in CSV.File(ENA_PATH))
end

end