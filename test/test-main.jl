using SDDPlab: SDDPlab
using Suppressor

@testset "main" begin
    @testset "main_success" begin
        e = CompositeException()
        using GLPK
        @suppress begin
            study = SDDPlab.read_study(example_dir; e = e)
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            SDDPlab.save_policy(study, policy, ".", SDDPlab.ParquetFormat())
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.load_policy(model, ".", SDDPlab.ParquetFormat())
            simulation = SDDPlab.simulate(study, model)
            SDDPlab.save_simulation(study, simulation, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end
end