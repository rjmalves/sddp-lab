
# OUTPUTS --------------------------------------------------------------------------------------

struct Outputs
    path::String
    policy::Bool
    simulation::Bool
end

function read_validate_outputs!(
    d::Dict{String,Any}, e::CompositeException
)::Union{Outputs,Nothing}
    valid = __validate_outputs!(d, e)
    if !valid
        return nothing
    end

    return valid ? Outputs(d["path"], d["policy"], d["simulation"]) : nothing
end

function write_outputs(o::Outputs, artifacts::Vector{TaskArtifact}, e::CompositeException)
    curdir = pwd()
    directory_exists = __validate_directory!(o.path, e)
    directory_exists || mkdir(o.path)
    cd(o.path)

    for a in artifacts
        write(a)
    end

    return cd(curdir)
end