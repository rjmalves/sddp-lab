
function train(
    model::SDDPModel, definition::SDDPPolicyTaskDefinition
)::SDDPPolicyTaskArtifact
    @info "Evaluating policy"
    max_iterations = definition.convergence.max_iterations
    stopping_rule = generate_stopping_rule(get_stopping_criteria(definition.convergence))
    risk_measure = generate_risk_measure(definition.risk_measure)
    parallel_scheme = generate_parallel_scheme(definition.parallel_scheme)
    SDDP.train(
        model.policy_graph;
        iteration_limit = max_iterations,
        stopping_rules = [stopping_rule],
        risk_measure = risk_measure,
        parallel_scheme = parallel_scheme,
        root_node_risk_measure = risk_measure,
    )
    return SDDPPolicyTaskArtifact(definition, model.policy_graph, definition.files)
end