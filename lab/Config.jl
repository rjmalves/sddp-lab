module Config

export ConfigData, from_json

struct UHEConfigData
    ghmin::Float64
    ghmax::Float64
    earmax::Float64
    initial_ear::Float64
    spill_penal::Float64
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
    uhe::UHEConfigData
    ute::UTEConfigData
    system::SystemConfigData
end

function from_json(jsondata::Dict{String, Any})::ConfigData
    uhe = UHEConfigData(jsondata["UHE"]["GHMIN"],
                        jsondata["UHE"]["GHMAX"],
                        jsondata["UHE"]["EARMAX"],
                        jsondata["UHE"]["EARM_INICIAL"],
                        jsondata["UHE"]["PENALIDADE_VERTIMENTO"])
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
                      uhe,
                      ute,
                      system)
end

end