"""
    train_model(model, cfg)

Wrapper para chamada de `SDDP.train` parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
  - `cfg::ConfigData`: configuracao do estudo como retornado por `Lab.Reader.read_config()`
"""
function train_model(model::SDDP.PolicyGraph, cfg::ConfigData)
    # Debug subproblema
    # SDDP.write_subproblem_to_file(model[1], "subproblem.lp")
    @info "Calculando política"
    return SDDP.train(model; iteration_limit = cfg.max_iterations)
end

"""
    simulate_model(model, cfg)

Realiza simulacao final parametrizada de acordo com configuracoes de estudo fornecidas

# Arguments

  - `model::SDDP.PolicyGraph`: modelo construido por `Lab.Study.build_model()`
"""
function simulate_model(model::SDDP.PolicyGraph)::Vector{Vector{Dict{Symbol,Any}}}
    SDDP.add_all_cuts(model)

    # TODO - get from inputs
    cycles_simulated_series = 10
    cycle_lenght = 12
    number_simulated_series = 300

    sampler = SDDP.InSampleMonteCarlo(;
        max_depth = cycles_simulated_series * cycle_lenght, terminate_on_dummy_leaf = false
    )
    @info "Realizando simulação"
    return SDDP.simulate(
        model,
        number_simulated_series,
        [:gt, :gh, :earm, :deficit, :vert, :ena];
        sampling_scheme = sampler,
        custom_recorders = Dict{Symbol,Function}(
            :cmo => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_energetico]),
            :vagua => (sp::JuMP.Model) -> JuMP.dual.(sp[:balanco_hidrico]),
            :custo_total => (sp::JuMP.Model) -> JuMP.objective_value(sp),
        ),
    )
end
