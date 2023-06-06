ENV["GKSwstype"] = "100"

include("lab/Lab.jl")

cfg = Lab.read_config()
ena = Lab.read_ena()
model = Lab.build_model(cfg, ena)
Lab.train_model(model, cfg)

sims = Lab.simulate_model(model, cfg)
Lab.write_simulation_results(sims, cfg)
Lab.plot_simulation_results(sims, cfg)

cuts = Lab.write_model_cuts(model)
Lab.plot_model_cuts(cuts, cfg)