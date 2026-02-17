function Lab.simulate(
    model::SDDPModel, definition::SDDPSimulationTaskDefinition
)::SDDPSimulationTaskArtifact
    sims = __simulate_model(model, definition)
    return SDDPSimulationTaskArtifact(definition, sims, model.scaling)
end

function __simulate_model(
    model::SDDPModel, definition::SDDPSimulationTaskDefinition
)::Vector{Vector{Dict{Symbol,Any}}}
    try
        SDDP.add_all_cuts(model.policy_graph)
    catch
        @warn "Error while adding all cuts for simulation"
    end
    graph_size = length(model.policy_graph.nodes)
    sampler = generate_sampling_scheme(definition.sampling_scheme, graph_size)
    parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)
    @info "Running simulation"
    return SDDP.simulate(
        model.policy_graph,
        definition.num_simulated_series,
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
end