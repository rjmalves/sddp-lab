using SDDPlab: SDDPlab
using Suppressor

@testset "study" begin
    @testset "study-sddp-read" begin
        e = CompositeException()
        study = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0
    end
    @testset "study-sddp-build" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            SDDPlab.build(study, GLPK.Optimizer)
        end
        @test length(e) == 0
    end
    @testset "study-sddp-train" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            model = SDDPlab.build(study, GLPK.Optimizer)
            artifact = SDDPlab.train(study, model)
        end
        @test length(e) == 0
    end
    @testset "study-sddp-save-policy" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            model = SDDPlab.build(study, GLPK.Optimizer)
            artifact = SDDPlab.train(study, model)
            SDDPlab.save_policy(study, artifact, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end
    @testset "study-sddp-load-policy" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.load_policy(model, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end
    @testset "study-sddp-simulate" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.train(study, model)
            artifact = SDDPlab.simulate(study, model)
        end
        @test length(e) == 0
    end
    @testset "study-sddp-save-simulation" begin
        e = CompositeException()
        using GLPK
        study = SDDPlab.read_study(example_dir; e = e)
        @suppress begin
            model = SDDPlab.build(study, GLPK.Optimizer)
            SDDPlab.train(study, model)
            artifact = SDDPlab.simulate(study, model)
            SDDPlab.save_simulation(study, artifact, ".", SDDPlab.ParquetFormat())
        end
        @test length(e) == 0
    end
end