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
if exec["ESCREVEOPERACAO"] Lab.write_simulation_results(sims, cfg) end
if exec["PLOTAOPERACAO"] Lab.plot_simulation_results(sims, cfg) end

cuts = Lab.write_model_cuts(model)
Lab.plot_model_cuts(cuts, cfg)