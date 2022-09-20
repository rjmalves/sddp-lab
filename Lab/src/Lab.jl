module Lab

include("Config.jl")
include("Reader.jl")
include("Writer.jl")
include("Study.jl")

using .Reader: read_config, read_ena
using .Writer: write_simulation_results, plot_simulation_results
using .Study: build_model, train_model, simulate_model

end
