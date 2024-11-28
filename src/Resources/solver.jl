# CLASS Solver -----------------------------------------------------------------------

function CLP(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_clp_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_clp_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_clp_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_clp_consistency!(d, e)

    return valid_consistency ? CLP(d) : nothing
end

function GLPK(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_glpk_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_glpk_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_glpk_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_glpk_consistency!(d, e)

    return valid_consistency ? GLPK(d) : nothing
end

function HiGHS(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_highs_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_highs_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_highs_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_highs_consistency!(d, e)

    return valid_consistency ? HiGHS(d) : nothing
end

function Gurobi(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_gurobi_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_gurobi_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_gurobi_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_gurobi_consistency!(d, e)

    return valid_consistency ? Gurobi(d) : nothing
end

# GENERAL METHODS -----------------------------------------------------------------------

function generate_optimizer(s::CLP)
    optimizer = optimizer_with_attributes(ClpInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

function generate_optimizer(s::GLPK)
    optimizer = optimizer_with_attributes(GLPKInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

function generate_optimizer(s::HiGHS)
    optimizer = optimizer_with_attributes(HiGHSInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

function generate_optimizer(s::Gurobi)
    optimizer = optimizer_with_attributes(GurobiInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

# HELPERS -------------------------------------------------------------------------------------

function __build_solver!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_solver_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "solver", e)
end

function __cast_solver_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
