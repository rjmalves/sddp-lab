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

    @testset "1dsin-pipeline" begin
        using GLPK
        example_1dsin = joinpath(@__DIR__, "..", "example", "1dsin")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_1dsin; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "1dsin_ar-pipeline" begin
        using GLPK
        example_1dsin_ar = joinpath(@__DIR__, "..", "example", "1dsin_ar")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_1dsin_ar; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    @testset "4ree-pipeline" begin
        using GLPK
        example_4ree = joinpath(@__DIR__, "..", "example", "4ree")
        @suppress begin
            e = CompositeException()
            study = SDDPlab.read_study(example_4ree; e = e)
            @test length(e) == 0
            model = SDDPlab.build(study, GLPK.Optimizer)
            policy = SDDPlab.train(study, model)
            @test policy !== nothing
            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end
end