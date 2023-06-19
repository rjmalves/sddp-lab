ENV["GKSwstype"] = "100"

include("src/Lab.jl")

exec = Lab.read_exec()
Lab.compute_simulate_policy(exec)
