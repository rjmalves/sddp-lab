# v3.0.0

## Breaking changes

- Engine configuration restructured: SDDP algorithm options now nested under `policy`, `simulation`, `diagnostics`, and `solver` objects
- `main()` CLI entrypoint replaced by modular task API (`read_study`, `build`, `train`, `simulate`, `validate`)

## New features

- **Non-controllable generation**: renewable generators (solar, wind) with per-stage uncertainty profiles and curtailment variables
- **Energy contracts**: bilateral energy contracts with min/max dispatch bounds and price-per-MWh objective contribution
- **Pumping stations**: pumped-storage units with coupled power/flow constraints and upstream/downstream hydro linkage
- **Inner load blocks**: within-stage load block representation for intraday demand resolution
- **Stage time duration**: configurable stage duration (hours) enabling flexible time horizons beyond monthly resolution
- **Inflow non-negativity**: optional truncation of negative inflow noise samples, configurable per engine
- **VAR stochastic process**: Vector AutoRegressive (VAR) model for spatially-correlated inflow scenario generation
- **Markov chain states**: Markov-switching inflow model with state-conditional distributions
- **Out-of-sample validation**: Monte Carlo policy evaluation against fresh scenario draws with 95% confidence intervals
- **Experiment management**: multi-configuration sweep runner with result aggregation and sensitivity analysis
- **Convergence diagnostics**: gap trajectory, statistical convergence detection, and JSON convergence report
- **Algorithm options**: `CutType`, `ForwardPass`, `DualityHandler`, `ScalingConfig`, `InflowNonNegativity` algorithm parameters
- **Parallelization**: `SDDP.Threaded()` parallel scheme support with thread-safe solver selection

## Misc

- Adds CI coverage reporting via Codecov (Julia 1.10 LTS + current release)
- Adds Julia formatter check to CI (Blue style via JuliaFormatter.jl)
- Adds full API reference documentation via Documenter.jl (docstrings on 80+ exported symbols)
- Adds Configuration Reference and Tutorial pages to documentation site
- Adds five tutorial examples with runnable configurations
- Switches CI matrix to Linux-only with `fail-fast: false` (mirrors SDDP.jl upstream)

## Fixes

- `get_input_module` now raises a descriptive error instead of `MethodError` on missing module type
- `save_simulation`, `save_policy`, `save_validation` restore working directory on exception via `try/finally`
- `EnergyContract.get_params` key corrected from `"contract_type"` to `"type"` to match input schema

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
- Insere novas variáveis de saída ao `operacao_sistema.csv`: `custo_presente`, `custo_futuro` e `custo_total`

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
