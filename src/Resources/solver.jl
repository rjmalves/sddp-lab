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
    valid_keys_types = __validate_glpk_keys_types!(d, e)
    valid_content = valid_keys_types ? __validate_glpk_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? GLPK() : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_solver!(d::Dict{String,Any}, e::CompositeException)::Bool
    solver_d = d["solver"]
    keys = ["name", "params"]
    keys_types = [String, Dict{String,Any}]
    valid_keys = __validate_keys!(solver_d, keys, e)
    valid_types = valid_keys && __validate_key_types!(solver_d, keys, keys_types, e)

    if !valid_types
        return false
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
