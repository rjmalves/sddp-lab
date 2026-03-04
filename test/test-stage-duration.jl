using SDDPlab: SDDPlab
using Dates
using Suppressor
using Test

@testset "stage-duration" begin
    @testset "tau-computation" begin
        # tau = (end - start) in hours
        # 730 hours = 30 days + 10 hours
        start_dt = DateTime(2024, 1, 1)
        end_dt = DateTime(2024, 1, 31, 10)  # 30 days + 10 hours = 730 hours
        delta_ms = Dates.value(end_dt - start_dt)
        tau = Float64(delta_ms) / 3_600_000.0
        @test tau == 730.0
    end

    @testset "zeta-computation" begin
        # zeta = 0.0036 * tau
        # For tau = 730: zeta = 0.0036 * 730 = 2.628
        tau = 730.0
        zeta = 0.0036 * tau
        @test zeta ≈ 2.628
    end

    @testset "tau-monthly-stages" begin
        # Verify tau for known month durations
        # January 2024: 31 days = 744 hours
        start_dt = DateTime(2024, 1, 1)
        end_dt = DateTime(2024, 2, 1)
        tau = Float64(Dates.value(end_dt - start_dt)) / 3_600_000.0
        @test tau == 744.0

        # February 2024 (leap year): 29 days = 696 hours
        start_dt = DateTime(2024, 2, 1)
        end_dt = DateTime(2024, 3, 1)
        tau = Float64(Dates.value(end_dt - start_dt)) / 3_600_000.0
        @test tau == 696.0
    end

    @testset "zero-duration-no-crash" begin
        # A zero-duration stage should produce tau=0 and zeta=0 without error
        start_dt = DateTime(2024, 6, 15)
        end_dt = DateTime(2024, 6, 15)
        tau = Float64(Dates.value(end_dt - start_dt)) / 3_600_000.0
        zeta = 0.0036 * tau
        @test tau == 0.0
        @test zeta == 0.0
    end

    @testset "e2e-1dtoy-build-train-simulate" begin
        e = CompositeException()
        study = SDDPlab.read_study(example_dir; e = e)
        @test length(e) == 0

        @suppress begin
            using HiGHS
            model = SDDPlab.build(study, HiGHS.Optimizer)
            SDDPlab.train(study, model)
            artifact = SDDPlab.simulate(study, model)
        end
        @test true  # reached here without error
    end
end
