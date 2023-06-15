module Config

export ConfigData

"""
   UHEConfigData

Classe contendo informacoes sobre uma UHE

Atributos da classe

 * `name::String`: indice da UHE no sistema
 * `ghmin::Float64`: geracao minima
 * `ghmax::Float64`: geracao maxima
 * `earmin::Float64`: energia armazenada minima
 * `earmax::Float64`: energia armazenada maxima
 * `initial_ear::Float64`: energia armazenada inicial
 * `spill_penal::Float64`: penalidade de vertimento
"""
struct UHEConfigData
    name::String
    ghmin::Float64
    ghmax::Float64
    earmin::Float64
    earmax::Float64
    initial_ear::Float64
    spill_penal::Float64
end

"""
    ParqueUHEConfigData

Classe contendo informacoes do parque hidroeletrico do sistema

Atributos da classe

 * `n_uhes::Int`: numero de UHEs no sistema
 * `uhes::Vector{UHEConfigData}`: vetor de objetos `UHEConfigData`
"""
struct ParqueUHEConfigData
    n_uhes::Int
    uhes::Vector{UHEConfigData}
end

"""
    ParqueUHEConfigData(uhes::Vector{UHEConfigData})

Constroi um `ParqueUHEConfigData` a partir de um vetor de `UHEConfigData`
"""
function ParqueUHEConfigData(uhes::Vector{UHEConfigData})
    n_uhes = length(uhes)
    ParqueUHEConfigData(n_uhes, uhes)
end

"""
    UHEConfigData

Classe contendo informacoes sobre uma UTE

Atributos da classe

 * `gtmin::Float64`: geracao minima da termica
 * `gtmax::Float64`: geracao maxima da termica
 * `generation_cost::Float64`: custo de geracao
"""
struct UTEConfigData
    gtmin::Float64
    gtmax::Float64
    generation_cost::Float64
end

"""
    SystemConfigData

Classe contendo informacoes gerais do sistema

Atributos da classe

 * `deficit_cost::Float64`: custo de deficit
 * `demand::Float64`: demanda (valor unico para todo o estudo)
"""
struct SystemConfigData
    deficit_cost::Float64
    demand::Float64
end

"""
    ConfigData

Classe contendo informacoes totais do estudo: UHEs, UTEs e Sistema

Atributos da classe

 * `initial_month::Int`: mes inicial do estudo
 * `years::Int`: numero de anos
 * `max_iterations::Int`: maximo numero de iteracoes para construcao da politica
 * `number_simulated_series::Int`: numero de series para a simulacao final
 * `scenarios_by_stage::Int`: numero de aberturas backward por estagio
 * `parque_uhe::ParqueUHEConfigData`: objeto `ParqueUHEConfigData` representando o parque hidro
 * `ute::UTEConfigData`: objeto `UTEConfigData` representando a termica
 * `system::SystemConfigData`: objeto `SystemConfigData` representando parametros gerais do sistema
"""
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

"""
    ConfigData(jsondata::Dict{String, Any})

Constroi um objeto `ConfigData` a partir de um dicionario lido do json `config.json` de entrada
"""
function ConfigData(jsondata::Dict{String, Any})::ConfigData
    uhes = map(
        x -> UHEConfigData(
            x["NOME"],
            x["GHMIN"],
            x["GHMAX"],
            x["EARMIN"],
            x["EARMAX"],
            x["EARM_INICIAL"],
            x["PENALIDADE_VERTIMENTO"]),
        jsondata["UHEs"])
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