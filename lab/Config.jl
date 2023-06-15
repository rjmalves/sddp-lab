module Config

export ConfigData

struct UHEConfigData
    index::Int
    name::String
    ghmin::Float64
    ghmax::Float64
    earmin::Float64
    earmax::Float64
    initial_ear::Float64
    spill_penal::Float64
end

struct ParqueUHEConfigData
    n_uhes::Int
    uhes::Vector{UHEConfigData}
end

function ParqueUHEConfigData(uhes::Vector{UHEConfigData})
    n_uhes = length(uhes)
    ParqueUHEConfigData(n_uhes, uhes)
end

struct UTEConfigData
    gtmin::Float64
    gtmax::Float64
    generation_cost::Float64
end

struct SystemConfigData
    deficit_cost::Float64
    demand::Float64
end

struct ConfigData
    initial_month::Int
    years::Int
    max_iterations::Int
    number_simulated_series::Int
    scenarios_by_stage::Int
    parque_uhe::ParqueUHEConfigData
    ute::UTEConfigData
    system::SystemConfigData
end

function ConfigData(jsondata::Dict{String,Any})::ConfigData
    uhesInput = jsondata["UHEs"]
    for (index, value) in enumerate(uhesInput)
        uhesInput[index]["INDEX"] = index
    end
    uhes = map(
        x -> UHEConfigData(x["INDEX"],
            x["NOME"],
            x["GHMIN"],
            x["GHMAX"],
            x["EARMIN"],
            x["EARMAX"],
            x["EARM_INICIAL"],
            x["PENALIDADE_VERTIMENTO"]),
        uhesInput)
    parque_uhe = ParqueUHEConfigData(uhes)

    ute = UTEConfigData(jsondata["UTE"]["GTMIN"],
        jsondata["UTE"]["GTMAX"],
        jsondata["UTE"]["CUSTO_GERACAO"])
    system = SystemConfigData(jsondata["SISTEMA"]["CUSTO_DEFICIT"],
        jsondata["SISTEMA"]["DEMANDA"])

    return ConfigData(jsondata["MES_INICIAL"],
        jsondata["ANOS"],
        jsondata["MAX_ITERACOES"],
        jsondata["NUMERO_SERIES_SIM_FINAL"],
        jsondata["NUMERO_CENARIOS_ESTAGIO"],
        parque_uhe,
        ute,
        system)
end

end