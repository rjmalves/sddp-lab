using Documenter, SDDPlab

makedocs(;
    pages = Any[
        "Introduction" => "index.md",
        "User Guide" => Any["Getting Started" => "man/getting_started.md"],
    ],
    sitename = "SDDPlab.jl",
)