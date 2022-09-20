module Reader

using JSON
using CSV
using ..Config

export read_config, read_ena

CONFIG_FILENAME = "config.json"
ENA_FILENAME = "ena.csv"

function read_config()::ConfigData
    return from_json(JSON.parsefile(CONFIG_FILENAME))
end

function read_ena()::Dict{Int,Vector{Float64}}
    return Dict((e.MES, [e.MEDIA, e.DESVIO])
                for e in CSV.File(ENA_FILENAME))
end

end