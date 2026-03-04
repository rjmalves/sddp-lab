using SDDPlab
using HiGHS
using Suppressor
using Test

examples_root = joinpath(@__DIR__, "..", "example")

@testset "tutorial-examples" begin
    @testset "renewable_contracts" begin
        @suppress begin
            study = SDDPlab.read_study(joinpath(examples_root, "renewable_contracts"))
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            SDDPlab.simulate(study, model)
        end
        @test true
    end

    @testset "pumped_storage" begin
        @suppress begin
            study = SDDPlab.read_study(joinpath(examples_root, "pumped_storage"))
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            SDDPlab.simulate(study, model)
        end
        @test true
    end

    @testset "load_blocks" begin
        @suppress begin
            study = SDDPlab.read_study(joinpath(examples_root, "load_blocks"))
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            SDDPlab.simulate(study, model)
        end
        @test true
    end

    @testset "markov_var" begin
        @suppress begin
            study = SDDPlab.read_study(joinpath(examples_root, "markov_var"))
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            SDDPlab.simulate(study, model)
        end
        @test true
    end

    @testset "experiment_sweep" begin
        @suppress begin
            exp_path = joinpath(examples_root, "experiment_sweep", "experiment.jsonc")
            SDDPlab.run_experiment(exp_path)
        end
        @test true

        @suppress begin
            sens_path = joinpath(examples_root, "experiment_sweep", "sensitivity.jsonc")
            SDDPlab.run_sensitivity(sens_path)
        end
        @test true
    end
end
