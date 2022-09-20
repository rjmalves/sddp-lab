using Comonicon

include("lab/Lab.jl")

"""
    Julia CLI for running SDDP studies.
"""
@main function sddp_lab()
    cfg = Lab.read_config()
    ena = Lab.read_ena()
    model = Lab.build_model(cfg, ena)
    Lab.train_model(model, cfg)
    sims = Lab.simulate_model(model, cfg)

    Lab.write_model_cuts(model)
    Lab.write_simulation_results(sims)
    Lab.plot_simulation_results(sims, cfg)
end
