module SDDPlab

include("Core/Core.jl")
include("Utils/Utils.jl")
include("StochasticProcess/StochasticProcess.jl")
include("System/System.jl")
include("Scenarios/Scenarios.jl")
include("Inputs/Inputs.jl")
include("Engines/Engines.jl")

include("study.jl")
include("study-validators.jl")

export read_study,
    build,
    train,
    save_policy,
    load_policy,
    simulate,
    save_simulation,
    CSVFormat,
    ParquetFormat

end
