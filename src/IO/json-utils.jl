function read_jsonc(filename::String)::Dict{String,Any}
    io = open(filename, "r")
    lines = readlines(io)
    close(io)
    lines .= replace.(lines, r"(?<!\\)//.*" => "")
    return JSON.parse(join(lines, "\n"))
end