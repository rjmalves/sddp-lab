# FILE READERS -------------------------------------------------------------------

function read_jsonc(filename::String)::Dict{String,Any}
    io = open(filename, "r")
    lines = readlines(io)
    close(io)
    lines .= replace.(lines, r"(?<!\\)//.*" => "")
    return JSON.parse(join(lines, "\n"))
end

function read_csv(filename::String)::DataFrame
    return DataFrame(
        CSV.File(
            filename;
            normalizenames = true,
            stripwhitespace = true,
            missingstring = "-",
            stringtype = String,
        ),
    )
end

# HELPERS -------------------------------------------------------------------

function __dataframe_to_dict(df::DataFrame)::Vector{Dict{String,Any}}
    columns = names(df)
    d::Vector{Dict{String,Any}} = []
    for i in 1:nrow(df)
        push!(d, Dict{String,Any}(name => df[i, name] for name in columns))
    end

    return d
end
