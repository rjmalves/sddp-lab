function simulate(
    model::SDDPModel, definition::SDDPSimulationTaskDefinition
)::SDDPSimulationTaskArtifact
    sims = __simulate_model(model, definition)
    return SDDPSimulationTaskArtifact(definition, sims, files)
end

# HELPERS -------------------------------------------------------------------------------------

function __simulate_model(
    model::SDDPModel, definition::SDDPSimulationTaskDefinition
)::Vector{Vector{Dict{Symbol,Any}}}
    try
        SDDP.add_all_cuts(model.policy_graph)
    catch
        @warn "Error while adding all cuts for simulation"
    end
    sampler = generate_sampler(get_algorithm(definition.files))
    parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)
    @info "Running simulation"
    simulation_result = SDDP.simulate(
        model.policy_graph,
        definition.number_simulated_series,
        [
            THERMAL_GENERATION,
            THERMAL_GENERATION_COST,
            INFLOW,
            TURBINED_FLOW,
            SPILLAGE,
            OUTFLOW,
            HYDRO_GENERATION,
            STORED_VOLUME,
            DEFICIT,
            NET_EXCHANGE,
            VERTEX_COVERAGE_DISTANCE,
        ];
        sampling_scheme = sampler,
        custom_recorders = Dict{Symbol,Function}(
            MARGINAL_COST => (sp::JuMP.Model) -> JuMP.dual.(sp[LOAD_BALANCE]),
            WATER_VALUE => (sp::JuMP.Model) -> JuMP.dual.(sp[HYDRO_BALANCE]),
            TOTAL_COST => (sp::JuMP.Model) -> JuMP.objective_value(sp),
        ),
        parallel_scheme = parallel_scheme,
        skip_undefined_variables = true,
    )
    return simulation_result
end