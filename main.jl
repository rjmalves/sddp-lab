ENV["GKSwstype"] = "100"

include("lab/Lab.jl")

exec = Lab.read_exec()
cfg = Lab.read_config(exec["INDIR"])
ena = Lab.read_ena(exec["INDIR"])

model = Lab.build_model(cfg, ena)
Lab.train_model(model, cfg)

if exec["ESCREVEOPERACAO"] || exec["PLOTAOPERACAO"]
    sims = Lab.simulate_model(model, cfg)
end
if exec["ESCREVEOPERACAO"] Lab.write_simulation_results(sims, cfg, exec["OUTDIR"]) end
if exec["PLOTAOPERACAO"] Lab.plot_simulation_results(sims, cfg, exec["OUTDIR"]) end

if exec["ESCREVECORTES"] || exec["PLOTACORTES"]
    cuts = Lab.get_model_cuts(model)
end
if exec["ESCREVECORTES"] Lab.write_model_cuts(cuts, exec["OUTDIR"]) end
if exec["PLOTACORTES"] Lab.plot_model_cuts(cuts, cfg, exec["OUTDIR"]) end

if exec["ESCREVEOPERACAO"] || exec["PLOTAOPERACAO"] || exec["ESCREVECORTES"] || exec["PLOTACORTES"]
    @info "Escrevendo eco dos arquivos de entrada em " * exec["OUTDIR"]
    cp(joinpath(exec["INDIR"], "config.json"), joinpath(exec["OUTDIR"], "config.json"), force=true)
    cp(joinpath(exec["INDIR"], "ena.csv"), joinpath(exec["OUTDIR"], "ena.csv"), force=true)
end

@info "Execucao completa"