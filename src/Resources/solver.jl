# CLASS Solver -----------------------------------------------------------------------

struct CLP <: Solver end
struct GLPK <: Solver end

function CLP(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_clp_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_clp_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? CLP() : nothing
end

function GLPK(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_clp_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_clp_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? GLPK() : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_solver!(d::Dict{String,Any}, e::CompositeException)::Bool
    solver_d = d["solver"]
    valid_keys = __validate_keys!(solver_d, ["name", "params"], e)
    valid_types = if valid_keys
        __validate_key_types!(risk_measure_d, ["name", "params"], [String, Dict{String,Any}], e)
    else
        false
    end
    valid = valid_keys && valid_types
    if !valid
        return nothing
    end

    name = solver_d["name"]
    params = solver_d["params"]

    solver_obj = nothing
    try
        name_type = getfield(@__MODULE__, Symbol(name))
        solver_obj = name_type(params, e)
    catch
        push!(e, AssertionError("Solver name ($name) not recognized"))
    end
    d["solver"] = solver_obj

    return solver_obj !== nothing
end
