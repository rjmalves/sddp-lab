function __validate_engine_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["engine"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["engine"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_sddp_engine_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(
        d,
        ["policy", "simulation", "diagnostics", "solver", "inflow_non_negativity"],
        e,
    )
    valid_types =
        valid_keys && __validate_key_types!(
            d,
            ["policy", "simulation", "diagnostics", "solver", "inflow_non_negativity"],
            [
                SDDPPolicyTaskDefinition,
                SDDPSimulationTaskDefinition,
                DiagnosticsConfig,
                SolverConfig,
                T where {T<:InflowNonNegativity},
            ],
            e,
        )
    # validation is Union{OutOfSampleValidation, Nothing} -- validate only if present
    if valid_types && haskey(d, "validation") && d["validation"] !== nothing
        valid_types = d["validation"] isa OutOfSampleValidation
        if !valid_types
            push!(
                e,
                ErrorException(
                    "Key 'validation' must be OutOfSampleValidation or nothing, got $(typeof(d["validation"]))",
                ),
            )
        end
    end
    return valid_types
end

function __build_sddp_engine_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_policy = __build_sddp_policy_task_definition!(d, e)
    valid_simulation = __build_sddp_simulation_task_definition!(d, e)
    valid_diagnostics = __build_diagnostics!(d, e)
    valid_solver = __build_solver!(d, e)
    valid_inflow = __build_inflow_non_negativity!(d, e)
    valid_validation = __build_validation!(d, e)
    return valid_policy &&
           valid_simulation &&
           valid_diagnostics &&
           valid_solver &&
           valid_inflow &&
           valid_validation
end
