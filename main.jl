ENV["GKSwstype"] = "100"

include("src/SDDPlab.jl")

exec = SDDPlab.read_exec()
SDDPlab.compute_simulate_policy(exec)
