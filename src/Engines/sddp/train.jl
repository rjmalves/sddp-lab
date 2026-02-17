
function Lab.train(
    model::SDDPModel, definition::SDDPPolicyTaskDefinition
)::SDDPPolicyTaskArtifact
    @info "Evaluating policy"
    max_iterations = definition.convergence.max_iterations
    stopping_rules = [
        generate_stopping_rule(sc) for sc in get_stopping_criteria(definition.convergence)
    ]
    risk_measure = generate_risk_measure(definition.risk_measure)
    parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)
    sampling_scheme = generate_sampling_scheme(definition.sampling_scheme)

    train_kwargs = Dict{Symbol,Any}(
        :iteration_limit => max_iterations,
        :stopping_rules => stopping_rules,
        :risk_measure => risk_measure,
        :parallel_scheme => parallel_scheme,
        :root_node_risk_measure => risk_measure,
        :sampling_scheme => sampling_scheme,
        :cut_type => generate_cut_type(definition.cut_type),
    )
    if !(definition.duality_handler isa DefaultDuality)
        train_kwargs[:duality_handler] =
            generate_duality_handler(definition.duality_handler)
    end
    if !(definition.forward_pass isa DefaultForwardPassStrategy)
        train_kwargs[:forward_pass] =
            generate_forward_pass(definition.forward_pass)
    end

    SDDP.train(model.policy_graph; train_kwargs...)
    return SDDPPolicyTaskArtifact(model.policy_graph)
end