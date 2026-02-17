function __validate_engine_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["engine"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["engine"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_sddp_engine_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, ["policy", "simulation", "diagnostics", "solver"], e)
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["policy", "simulation", "diagnostics", "solver"],
            [SDDPPolicyTaskDefinition, SDDPSimulationTaskDefinition, DiagnosticsConfig, SolverConfig],
            e,
        )
    return valid_types
end

function __build_sddp_engine_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_policy = __build_sddp_policy_task_definition!(d, e)
    valid_simulation = __build_sddp_simulation_task_definition!(d, e)
    valid_diagnostics = __build_diagnostics!(d, e)
    valid_solver = __build_solver!(d, e)
    return valid_policy && valid_simulation && valid_diagnostics && valid_solver
end
