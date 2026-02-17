import SDDPlab: Engines

using SDDP: SDDP

INSAMPLE_MC_DICT =
    convert(Dict{String,Any}, Dict("max_depth" => 12, "terminate_on_dummy_leaf" => false))
PSR_SAMPLING_DICT = convert(Dict{String,Any}, Dict("num_samples" => 100))
DEFAULT_SAMPLING_DICT = convert(Dict{String,Any}, Dict())

@testset "engines-sddp-sampling-schemes" begin

    @testset "default-sampling-valid" begin
        d, e = __renew(DEFAULT_SAMPLING_DICT)
        result = Engines.DefaultSampling(d, e)
        @test typeof(result) === Engines.DefaultSampling
        @test length(e) == 0
    end

    @testset "insample-mc-valid" begin
        d, e = __renew(INSAMPLE_MC_DICT)
        result = Engines.InSampleMC(d, e)
        @test typeof(result) === Engines.InSampleMC
        @test result.max_depth == 12
        @test result.terminate_on_dummy_leaf == false
        @test length(e) == 0
    end

    @testset "insample-mc-invalid-max-depth-zero" begin
        d, e = __renew(INSAMPLE_MC_DICT)
        d = __modif_key(d, "max_depth", 0)
        @test Engines.InSampleMC(d, e) === nothing
        @test length(e) > 0
    end

    @testset "insample-mc-invalid-max-depth-negative" begin
        d, e = __renew(INSAMPLE_MC_DICT)
        d = __modif_key(d, "max_depth", -5)
        @test Engines.InSampleMC(d, e) === nothing
        @test length(e) > 0
    end

    @testset "insample-mc-missing-max-depth" begin
        d = convert(Dict{String,Any}, Dict("terminate_on_dummy_leaf" => false))
        e = CompositeException()
        @test Engines.InSampleMC(d, e) === nothing
        @test length(e) > 0
    end

    @testset "insample-mc-missing-terminate-on-dummy-leaf" begin
        d = convert(Dict{String,Any}, Dict("max_depth" => 12))
        e = CompositeException()
        @test Engines.InSampleMC(d, e) === nothing
        @test length(e) > 0
    end

    @testset "psr-sampling-valid" begin
        d, e = __renew(PSR_SAMPLING_DICT)
        result = Engines.PSRSampling(d, e)
        @test typeof(result) === Engines.PSRSampling
        @test result.num_samples == 100
        @test length(e) == 0
    end

    @testset "psr-sampling-invalid-num-samples-zero" begin
        d, e = __renew(PSR_SAMPLING_DICT)
        d = __modif_key(d, "num_samples", 0)
        @test Engines.PSRSampling(d, e) === nothing
        @test length(e) > 0
    end

    @testset "psr-sampling-invalid-num-samples-negative" begin
        d, e = __renew(PSR_SAMPLING_DICT)
        d = __modif_key(d, "num_samples", -10)
        @test Engines.PSRSampling(d, e) === nothing
        @test length(e) > 0
    end

    @testset "psr-sampling-missing-num-samples" begin
        d = convert(Dict{String,Any}, Dict())
        e = CompositeException()
        @test Engines.PSRSampling(d, e) === nothing
        @test length(e) > 0
    end

    @testset "generate-sampling-scheme-default" begin
        scheme = Engines.generate_sampling_scheme(Engines.DefaultSampling())
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) === SDDP.InSampleMonteCarlo
    end

    @testset "generate-sampling-scheme-default-with-graph-size" begin
        scheme = Engines.generate_sampling_scheme(Engines.DefaultSampling(), 12)
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) === SDDP.InSampleMonteCarlo
        @test scheme.max_depth == 12
        @test scheme.terminate_on_dummy_leaf == false
    end

    @testset "generate-sampling-scheme-insample-mc" begin
        scheme = Engines.generate_sampling_scheme(Engines.InSampleMC(12, false))
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) === SDDP.InSampleMonteCarlo
        @test scheme.max_depth == 12
        @test scheme.terminate_on_dummy_leaf == false
    end

    @testset "generate-sampling-scheme-insample-mc-with-graph-size" begin
        scheme = Engines.generate_sampling_scheme(Engines.InSampleMC(5, true), 100)
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) === SDDP.InSampleMonteCarlo
        @test scheme.max_depth == 5
        @test scheme.terminate_on_dummy_leaf == true
    end

    @testset "generate-sampling-scheme-psr" begin
        scheme = Engines.generate_sampling_scheme(Engines.PSRSampling(100))
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) <: SDDP.PSRSamplingScheme
    end

    @testset "generate-sampling-scheme-psr-with-graph-size" begin
        scheme = Engines.generate_sampling_scheme(Engines.PSRSampling(50), 12)
        @test scheme isa SDDP.AbstractSamplingScheme
        @test typeof(scheme) <: SDDP.PSRSamplingScheme
    end

    @testset "sampling-scheme-kind-factory-insample-mc" begin
        d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
            "sampling_scheme" => Dict{String,Any}(
                "kind" => "InSampleMC",
                "params" => Dict{String,Any}(
                    "max_depth" => 12, "terminate_on_dummy_leaf" => false
                ),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPSimulationTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPSimulationTaskDefinition
        @test typeof(result.sampling_scheme) === Engines.InSampleMC
        @test result.sampling_scheme.max_depth == 12
    end

    @testset "sampling-scheme-kind-factory-psr" begin
        d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
            "sampling_scheme" => Dict{String,Any}(
                "kind" => "PSRSampling",
                "params" => Dict{String,Any}("num_samples" => 50),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPSimulationTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.sampling_scheme) === Engines.PSRSampling
        @test result.sampling_scheme.num_samples == 50
    end

    @testset "sampling-scheme-kind-factory-default" begin
        d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
            "sampling_scheme" => Dict{String,Any}(
                "kind" => "DefaultSampling", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPSimulationTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.sampling_scheme) === Engines.DefaultSampling
    end

    @testset "sampling-scheme-backward-compat-simulation" begin
        d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPSimulationTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.sampling_scheme) === Engines.DefaultSampling
    end

    @testset "sampling-scheme-backward-compat-policy" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" => Dict{String,Any}(
                "kind" => "Expectation", "params" => Dict{String,Any}()
            ),
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.sampling_scheme) === Engines.DefaultSampling
    end

    @testset "sampling-scheme-policy-explicit-insample-mc" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" => Dict{String,Any}(
                "kind" => "Expectation", "params" => Dict{String,Any}()
            ),
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
            "sampling_scheme" => Dict{String,Any}(
                "kind" => "InSampleMC",
                "params" => Dict{String,Any}(
                    "max_depth" => 24, "terminate_on_dummy_leaf" => true
                ),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result.sampling_scheme) === Engines.InSampleMC
        @test result.sampling_scheme.max_depth == 24
        @test result.sampling_scheme.terminate_on_dummy_leaf == true
    end

    @testset "sampling-scheme-invalid-kind" begin
        d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}(
                "kind" => "Serial", "params" => Dict{String,Any}()
            ),
            "sampling_scheme" => Dict{String,Any}(
                "kind" => "NonExistentSampling",
                "params" => Dict{String,Any}(),
            ),
        )
        e = CompositeException()
        result = Engines.SDDPSimulationTaskDefinition(d, e)
        @test result === nothing
        @test length(e) > 0
    end
end
