using Suppressor

@testset "Test Cases" begin

    @testset "Basic" begin
        @suppress begin
            exec = SDDPlab.read_exec("data/")
            SDDPlab.compute_simulate_policy(exec)
        end
    end

    @testset "Periodic" begin
        @suppress begin
            exec = SDDPlab.read_exec("data_per/")
            SDDPlab.compute_simulate_policy(exec)
        end
    end

    @testset "Weekly" begin
        @suppress begin
            exec = SDDPlab.read_exec("data_semanal/")
            SDDPlab.compute_simulate_policy(exec)
        end
    end

end