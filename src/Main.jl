"""
    compute_simulate_policy(execution)

Realiza um estudo completo: aproxima politica, realiza simulacao e escreve todos os resultados

# Arguments

  - `execution::Dict{String,Any}`: dicionario de parametros de execucao (arquivo execucao.json)
"""
function compute_simulate_policy(execution::Dict{String,Any})
    cfg = read_config(execution["INDIR"])
    ena = read_ena(execution["INDIR"], cfg)

    model = build_model(cfg, ena)
    train_model(model, cfg)

    if execution["ESCREVEOPERACAO"] || execution["PLOTAOPERACAO"]
        sims = simulate_model(model, cfg)
    end
    if execution["ESCREVEOPERACAO"]
        write_simulation_results(sims, cfg, execution["OUTDIR"])
    end
    if execution["PLOTAOPERACAO"]
        plot_simulation_results(sims, cfg, execution["OUTDIR"])
    end

    if execution["ESCREVECORTES"] || execution["PLOTACORTES"]
        cuts = get_model_cuts(model)
    end
    if execution["ESCREVECORTES"]
        write_model_cuts(cuts, execution["OUTDIR"])
    end
    if execution["PLOTACORTES"]
        plot_model_cuts(cuts, cfg, execution["OUTDIR"])
    end

    if execution["ESCREVEOPERACAO"] ||
        execution["PLOTAOPERACAO"] ||
        execution["ESCREVECORTES"] ||
        execution["PLOTACORTES"]
        @info "Escrevendo eco dos arquivos de entrada em " * execution["OUTDIR"]
        cp(
            joinpath(execution["INDIR"], "config.json"),
            joinpath(execution["OUTDIR"], "config.json");
            force = true,
        )
        cp(
            joinpath(execution["INDIR"], "ena.csv"),
            joinpath(execution["OUTDIR"], "ena.csv");
            force = true,
        )
    end

    @info "Execucao completa"
end

function main()
    e = CompositeException()
    d = read_validate_entrypoint!("main.jsonc", e)
    inputs = read_validate_inputs!(d["inputs"], e)
    outputs = read_validate_outputs!(d["outputs"], e)
    tasks = read_validate_tasks!(d["tasks"], inputs, e)
    artifacts = run_tasks!(tasks, e)
    return write_outputs(outputs, artifacts, e)
end