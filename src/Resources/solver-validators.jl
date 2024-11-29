# KEYS / TYPES VALIDATORS -------------------------------------------------------------------

function __validate_solver_main_key_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_keys = __validate_keys!(d, ["solver"], e)
    valid_types = valid_keys && __validate_key_types!(d, ["solver"], [Dict{String,Any}], e)
    return valid_types
end

function __validate_clp_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_glpk_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_highs_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_gurobi_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_cplex_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_clp_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_glpk_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_highs_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_gurobi_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __validate_cplex_content!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_clp_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    optimizer = generate_optimizer(CLP(d))
    valid = true
    try
        JuMP.Model(optimizer)
    catch
        valid = false
        push!(e, AssertionError("$d is not a valid parameter set for Clp solver."))
    end
    return valid
end

function __validate_glpk_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    optimizer = generate_optimizer(GLPK(d))
    valid = true
    try
        JuMP.Model(optimizer)
    catch
        valid = false
        push!(e, AssertionError("$d is not a valid parameter set for GLPK solver."))
    end
    return valid
end

function __validate_highs_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    optimizer = generate_optimizer(HiGHS(d))
    valid = true
    try
        JuMP.Model(optimizer)
    catch
        valid = false
        push!(e, AssertionError("$d is not a valid parameter set for HiGHS solver."))
    end
    return valid
end

function __validate_gurobi_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    optimizer = generate_optimizer(Gurobi(d))
    valid = true
    try
        JuMP.Model(optimizer)
    catch
        valid = false
        push!(e, AssertionError("$d is not a valid parameter set for Gurobi solver."))
    end
    return valid
end

function __validate_cplex_consistency!(d::Dict{String,Any}, e::CompositeException)::Bool
    optimizer = generate_optimizer(CPLEX(d))
    valid = true
    try
        JuMP.Model(optimizer)
    catch
        valid = false
        push!(e, AssertionError("$d is not a valid parameter set for CPLEX solver."))
    end
    return valid
end

# HELPERS -----------------------------------------------------------------------------------

function __build_clp_internals_from_dicts!(d::Dict{String,Any}, e::CompositeException)::Bool
    return true
end

function __build_glpk_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_highs_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_gurobi_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end

function __build_cplex_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
