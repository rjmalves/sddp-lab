using SDDPlab

exec = SDDPlab.read_exec("data/")
SDDPlab.compute_simulate_policy(exec)

exec = SDDPlab.read_exec("data_per/")
SDDPlab.compute_simulate_policy(exec)