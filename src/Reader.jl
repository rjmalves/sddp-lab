using JSON
using CSV
using DataFrames
using Logging

"""
    read_config(INDIR::String)
    
Le um arquivo de configuracao de estudo `config.json` localizado no diretorio `INDIR`

Retorna objeto `Lab.Config.ConfigData`. Para mais detalhes, ver sua documentacao.

# Arguments

 * `INDIR`: diretório para leitura do arquivo
"""
function read_config(INDIR::String)::ConfigData
    CONFIG_PATH = joinpath(INDIR, "config.json")
    @info "Lendo arquivo de configuração $(CONFIG_PATH)"
    return ConfigData(JSON.parsefile(CONFIG_PATH))
end

"""
    read_ena(INDIR, CFG)

Le um arquivo de ENAs para o estudo `ena.csv` localizado no diretorio `INDIR`, recebendo as
configurações do estudo `CFG` para armazenamento ordenado das informações.

# Arguments

 * `INDIR`: diretório para leitura do arquivo
 * `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
 

# Extended help

O objeto retornado e um dicionario contendo as informacoes acerca das ENAs para cada UHE e cada mes.
O primeiro nivel do dicionario diz respeito as UHEs, cujas chaves sao nomeadas de acordo com o 
valor na coluna `UHE` do arquivo `ena.csv`. Cada elemento de primeiro nivel e, tambem, um 
dicionario. Estes sao todos de `cfg.cycle_lenght` elementos,
correspondendo a meses/semanas/... de um modelo periódico,
cujas chaves sao numeradas `"1", "2", ..., "cfg.cycle_lenght"`. Os valores de cada elemento sao vetores de duas posicoes: media e desvio 
padrao de uma normal da qual amostrar valores de ENA naquele estágio, para aquela UHE.

Exemplo de dicionario com uma unica UHE

```julia
Dict(1 => 
    Dict(
        5 => [50.0, 5.0],
        12 => [45.0, 4.5],
        8 => [25.0, 2.5],
        1 => [70.0, 7.0],
        6 => [45.0, 4.5],
        11 => [35.0, 3.5],
        9 => [20.0, 2.0],
        3 => [95.0, 9.5],
        7 => [35.0, 3.5],
        4 => [60.0, 6.0],
        2 => [80.0, 8.0],
        10 => [20.0, 2.0]
    )
)
```
"""
function read_ena(INDIR::String, CFG::ConfigData)::Dict{Int,Dict{Int,Vector{Float64}}}
    ENA_PATH = joinpath(INDIR, "ena.csv")
    @info "Lendo arquivo de configuração $(ENA_PATH)"
    dat_ena = CSV.read(ENA_PATH, DataFrame)
    stage_name = names(dat_ena)[2]
    uhes = unique(dat_ena[:, :UHE])
    uhes_ordenadas = map(uhe -> uhe.name, CFG.parque_uhe.uhes)
    out = Dict()
    for u in uhes
        aux = Dict((e[Symbol(stage_name)], [e.MEDIA, e.DESVIO])
                   for e in CSV.File(ENA_PATH) if e.UHE == u)
        indice_u = findfirst(item -> item == string("", u), uhes_ordenadas)
        out[indice_u] = aux
    end

    return out
end

"""
    read_exec()

Le um arquivo parametros de execucao do estudo `execucao.json`

Diferente das demais funcoes leitoras, `read_exec()` nao recebe argumento. Caso o julia seja 
inicializado com um argumento correspondendo ao caminho de um `execucao.json`, este sera usado; do
contrario, le no diretorio de entrada default `./data`.
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
    read_exec(INDIR)

Le um arquivo parametros de execucao do estudo `execucao.json` localizado em `INDIR`.

# Arguments
    
 * `INDIR`: diretório para leitura do arquivo
"""
function read_exec(INDIR::String)::Dict{String,Any}
    EXEC_PATH = joinpath(INDIR, "execucao.json")
    @info "Lendo arquivo de execucao $(EXEC_PATH)"
    out = JSON.parsefile(EXEC_PATH)
    return out
end
