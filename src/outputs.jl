
# OUTPUTS --------------------------------------------------------------------------------------

struct Outputs
    path::String
    policy::Bool
    simulation::Bool
    plots::Bool
end

function read_validate_outputs!(
    d::Dict{String,Any}, e::CompositeException
)::Union{Outputs,Nothing}
    valid = __validate_outputs!(d, e)
    if !valid
        return nothing
    end

    return valid ? Outputs(d["path"], d["policy"], d["simulation"], d["plots"]) : nothing
end
