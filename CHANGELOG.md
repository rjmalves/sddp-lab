# v2.0.0

## New features

- Supports Asynchronous execution using SDDP.jl implementation (#14)
- Adds buses and lines as system elements (#11, #12)
- Function `main()` now takes two required arguments: `data_dir` and `optimizer`
- Adds support to abstract Stochastic Processes for inflow, with Naive and AutoRegressive implemented
- Execution modularized in Tasks, enabling to run only policy evaluation or simulation separately
- Supports general SDDP.jl abstractions via parameters in the input files: Graph, StoppingCriteria, RiskMeasure, etc.

## Misc

- Refactors all input data format to a mix of CSV and JSONC files (#33)
- Refactors all simulation output data format to normalized tabular in CSV or PARQUET (#28)
- Refactors policy output data (cuts) and exports convergence data in normalized tabular formats (#13)
- Unifies package language to english (#19)
- Updates julia version used in development to 1.11

## Fixes

- PackageCompiler compatibility restored (#15)

# v1.0.2

## New features

- Altera formulação no cálculo dos cortes para uso nos gráficos de FCF com uma dimensão para ser compatível com a usada pelo `SDDP.jl`
- Insere novas variáveis de saída ao `operacao_sistema.csv`: `custo_presente`,   `custo_futuro` e `custo_total`

## Misc

- Semente para geração dos números aleatórios fixada dentro das funções que utilizam amostragem
- Adiciona CHANGELOG ao repositório

# v1.0.1

## New features

- Permite instalação como pacote a partir do repositório, realizando a configuração do ambiente conforme consta no `README.md`

## Misc

- Módulo renomeado para `SDDPlab`

# v1.0.0

- Execução permite escolher o mês de início do estudo e quantos anos ele dura, com resolução mensal
- Convergência por número máximo de iterações
- Permite escolher o número de cenários por estágio e número de séries para a simulação final
- Mercado de energia único, com demanda constante e custo de déficit
- Única UTE, com inflexibilidade, custo e capacidade de geração máxima constantes 
- Número variável de UHEs, cada uma com suas respectivas características: nome, ghmin, ghmax, earmin, earmax e penalidade de vertimento
- As UHEs podem ser organizadas em cascata através da opção `JUSANTE` no arquivo de configuração
- As afluências de cada UHE são amostradas de uma normal com média e variância configuráveis por mês

