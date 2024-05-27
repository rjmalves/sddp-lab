module Config

export ConfigData

"""
UHEConfigData

Classe contendo informacoes sobre uma UHE

Atributos da classe

  - `name::String`: nome da UHE no sistema
  - `downstream::String`: nome da UHE à jusante, se houver
  - `ghmin::Float64`: geracao minima
  - `ghmax::Float64`: geracao maxima
  - `earmin::Float64`: energia armazenada minima
  - `earmax::Float64`: energia armazenada maxima
  - `initial_ear::Float64`: energia armazenada inicial
  - `spill_penal::Float64`: penalidade de vertimento
"""
struct UHEConfigData
    name::String
    downstream::String
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

  - `n_uhes::Int`: numero de UHEs no sistema
  - `uhes::Vector{UHEConfigData}`: vetor de objetos `UHEConfigData`
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
    return ParqueUHEConfigData(n_uhes, uhes)
end

"""
    UTEConfigData

Classe contendo informacoes sobre uma UTE

Atributos da classe

  - `gtmin::Float64`: geracao minima da termica
  - `gtmax::Float64`: geracao maxima da termica
  - `generation_cost::Float64`: custo de geracao
"""
struct UTEConfigData
    gtmin::Float64
    gtmax::Float64
    generation_cost::Float64
end

"""
    ParqueUTEConfigData

Classe contendo informacoes do parque termico do sistema

Atributos da classe

  - `n_utes::Int`: numero de UTEs no sistema
  - `utes::Vector{UTEConfigData}`: vetor de objetos `UTEConfigData`
"""
struct ParqueUTEConfigData
    n_utes::Int
    utes::Vector{UTEConfigData}
end

"""
    ParqueUTEConfigData(utes::Vector{UTEConfigData})

Constroi um `ParqueUTEConfigData` a partir de um vetor de `UTEConfigData`
"""
function ParqueUTEConfigData(utes::Vector{UTEConfigData})
    n_utes = length(utes)
    return ParqueUTEConfigData(n_utes, utes)
end
"""
    SystemConfigData

Classe contendo informacoes gerais do sistema

Atributos da classe

  - `deficit_cost::Float64`: custo de deficit
  - `demand::Float64`: demanda (valor unico para todo o estudo)
"""
struct SystemConfigData
    deficit_cost::Float64
    demand::Float64
end

"""
    ConfigData

Classe contendo informacoes totais do estudo: UHEs, UTEs e Sistema

Atributos da classe

  - `initial_month::Int`: mes inicial do estudo
  - `cycles::Int`: numero de ciclos (caso não-periódico)
  - `discout_factor::Float64`: fator de desconto
  - `discout_by_stage::Bool`: o valor do desconto eh por estagio
  - `discout_by_cycle::Bool`: o valor do desconto eh por ciclo
  - `cyclic::Bool`: o estudo eh ciclico
  - `cycle_lenght::Int`: tamanho do ciclo
  - `max_iterations::Int`: maximo numero de iteracoes para construcao da politica
  - `number_simulated_series::Int`: numero de series para a simulacao final
  - `cycles_simulated_series::Int`: numero de períodos para a simulacao final
  - `scenarios_by_stage::Int`: numero de aberturas backward por estagio
  - `parque_uhe::ParqueUHEConfigData`: objeto `ParqueUHEConfigData` representando o parque hidro
  - `parque_ute::ParqueUTEConfigData`: objeto `ParqueUTEConfigData` representando o parque termico
  - `system::SystemConfigData`: objeto `SystemConfigData` representando parametros gerais do sistema
"""
struct ConfigData
    initial_month::Int
    cycles::Int
    discout_factor::Float64
    discout_by_stage::Bool
    discout_by_cycle::Bool
    cyclic::Bool
    cycle_lenght::Int
    max_iterations::Int
    number_simulated_series::Int
    cycles_simulated_series::Int
    scenarios_by_stage::Int
    parque_uhe::ParqueUHEConfigData
    parque_ute::ParqueUTEConfigData
    system::SystemConfigData
end

"""
    ConfigData(jsondata::Dict{String, Any})

Constroi um objeto `ConfigData` a partir de um dicionario lido do json `config.json` de entrada
"""
function ConfigData(jsondata::Dict{String,Any})::ConfigData
    uhes = map(
        x -> UHEConfigData(
            x["NOME"],
            x["JUSANTE"],
            x["GHMIN"],
            x["GHMAX"],
            x["EARMIN"],
            x["EARMAX"],
            x["EARM_INICIAL"],
            x["PENALIDADE_VERTIMENTO"],
        ),
        jsondata["UHEs"],
    )
    parque_uhe = ParqueUHEConfigData(uhes)

    utes = map(
        x -> UTEConfigData(x["GTMIN"], x["GTMAX"], x["CUSTO_GERACAO"]), jsondata["UTEs"]
    )
    parque_ute = ParqueUTEConfigData(utes)

    system = SystemConfigData(
        jsondata["SISTEMA"]["CUSTO_DEFICIT"], jsondata["SISTEMA"]["DEMANDA"]
    )

    if jsondata["DESCONTO_ESTAGIO"] && jsondata["DESCONTO_CICLO"] && jsondata["CICLICO"]
        @warn "Desconto por estágio e ciclo ativados simultaneamente. Será considerado como desconto por ciclo."
    end

    return ConfigData(
        jsondata["MES_INICIAL"],
        jsondata["CICLOS"],
        jsondata["TAXA_DESCONTO"],
        jsondata["DESCONTO_ESTAGIO"],
        jsondata["DESCONTO_CICLO"],
        jsondata["CICLICO"],
        jsondata["PERIODO_CICLO"],
        jsondata["MAX_ITERACOES"],
        jsondata["NUMERO_SERIES_SIM_FINAL"],
        jsondata["CICLOS_SIM_FINAL"],
        jsondata["NUMERO_CENARIOS_ESTAGIO"],
        parque_uhe,
        parque_ute,
        system,
    )
end

end