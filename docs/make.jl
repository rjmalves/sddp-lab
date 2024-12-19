using Documenter, SDDPlab

format = Documenter.HTML(;
    edit_link = "main",
    prettyurls = get(ENV, "CI", nothing) == "true",
    assets = [joinpath("assets", "favicon.ico")],
)

makedocs(;
    # modules = [SDDPlab],
    sitename = "SDDPlab.jl",
    format = format,
    checkdocs = :exports,
    pages = [
        "Introduction" => "index.md",
        "User Guide" => ["Getting Started" => "man/getting_started.md"],
    ],
)