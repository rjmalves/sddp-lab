
@testset "Test Cases" begin

    @testset "Basic" begin
        exec = SDDPlab.read_exec("data/")
        SDDPlab.compute_simulate_policy(exec)
    end

    @testset "Periodic" begin
        exec = SDDPlab.read_exec("data_per/")
        SDDPlab.compute_simulate_policy(exec)
    end

    @testset "Weekly" begin
        exec = SDDPlab.read_exec("data_semanal/")
        SDDPlab.compute_simulate_policy(exec)
    end

end