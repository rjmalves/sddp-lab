using JSON
using CSV

# FILE READERS -------------------------------------------------------------------

function read_jsonc(filename::String)::Dict{String,Any}
    open(filename) do io
        lines = readlines(io)
        lines .= replace.(lines, r"(?<!\\)//.*" => "")
        return JSON.parse(join(lines, "\n"))
    end
end

function read_csv(filename::String)::DataFrame
    csv_file = CSV.File(
        filename;
        normalizenames = true,
        stripwhitespace = true,
        missingstring = "-",
        stringtype = String,
    )
    return DataFrame(csv_file)
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
