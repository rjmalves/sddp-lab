using Documenter, SDDPlab

format = Documenter.HTML(;
    edit_link = "main",
    prettyurls = get(ENV, "CI", nothing) == "true",
    assets = [joinpath("assets", "favicon.ico")],
)

makedocs(;
    modules = [
        SDDPlab,
        SDDPlab.Lab,
        SDDPlab.System,
        SDDPlab.Scenarios,
        SDDPlab.StochasticProcess,
        SDDPlab.Engines,
    ],
    sitename = "SDDPlab.jl",
    format = format,
    checkdocs = :exports,
    warnonly = true,
    pages = [
        "Introduction" => "index.md",
        "User Guide" => [
            "Installation" => "man/installation.md",
            "Getting Started" => "man/getting_started.md",
        ],
        "Configuration Reference" => [
            "Overview" => "configuration/overview.md",
            "System" => "configuration/system.md",
            "Scenarios" => "configuration/scenarios.md",
            "Engine" => "configuration/engine.md",
            "Experiments" => "configuration/experiments.md",
        ],
        "Tutorials" => [
            "Renewable Generation & Contracts" => "tutorials/renewable_contracts.md",
            "Pumped Storage" => "tutorials/pumped_storage.md",
            "Inner Load Blocks" => "tutorials/load_blocks.md",
            "Markov Chain Inflow States" => "tutorials/markov_var.md",
            "Experiments & Sensitivity" => "tutorials/experiment_sweep.md",
        ],
        "API Reference" => [
            "Core Pipeline" => "api/pipeline.md",
            "System Elements" => "api/system.md",
            "Scenarios" => "api/scenarios.md",
            "Stochastic Processes" => "api/stochastic.md",
            "Engine Configuration" => "api/engine.md",
            "Experiments" => "api/experiments.md",
            "Observability" => "api/observability.md",
            "Variable Symbols & Formats" => "api/variables.md",
        ],
    ],
)

deploydocs(; repo = "github.com/rjmalves/sddp-lab.git")
