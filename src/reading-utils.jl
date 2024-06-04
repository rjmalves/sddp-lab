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
