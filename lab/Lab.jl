module Lab

using Random

Random.seed!(0)

include("Config.jl")
include("Reader.jl")
include("Writer.jl")
include("Study.jl")

using .Reader: read_config, read_ena
using .Writer: write_simulation_results, write_model_cuts, plot_simulation_results, plot_model_cuts
using .Study: build_model, train_model, simulate_model

end
