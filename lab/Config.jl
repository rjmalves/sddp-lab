module Config

export ConfigData

struct UHEConfigData
    index::Int
    ghmin::Float64
    ghmax::Float64
    earmax::Float64
    initial_ear::Float64
    spill_penal::Float64
end

struct ParqueUHEConfigData
    n_uhes::Int
    order_uhes::Vector{Int}
    uhes::Vector{UHEConfigData}
end

function ParqueUHEConfigData(uhes::Vector{UHEConfigData})
    n_uhes = length(uhes)
    order_uhes = map(x -> x.index, uhes)
    ParqueUHEConfigData(n_uhes, order_uhes, uhes)
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

function ConfigData(jsondata::Dict{String, Any})::ConfigData
    uhes = map(
        x -> UHEConfigData(x["INDEX"],
                           x["GHMIN"],
                           x["GHMAX"],
                           x["EARMAX"],
                           x["EARM_INICIAL"],
                           x["PENALIDADE_VERTIMENTO"]),
        values(jsondata["UHEs"]))
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