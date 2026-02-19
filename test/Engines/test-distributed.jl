import SDDPlab: Engines
using Distributed
using SDDP: SDDP

CONVERGENCE_DICT_D = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 128,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "IterationLimit",
        "params" => Dict{String,Any}("num_iterations" => 128),
    ),
)

RISK_MEASURE_DICT_D = Dict{String,Any}(
    "kind" => "CVaR", "params" => Dict{String,Any}("alpha" => 0.2, "lambda" => 0.9)
)

@testset "engines-distributed" begin
    @testset "asynchronous-from-valid-dict" begin
        policy_d = Dict{String,Any}(
            "convergence" => deepcopy(CONVERGENCE_DICT_D),
            "risk_measure" => deepcopy(RISK_MEASURE_DICT_D),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Asynchronous", "params" => Dict{String,Any}()),
        )
        sim_d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        d = Dict{String,Any}(
            "engine" => Dict{String,Any}(
                "kind" => "SDDPEngine",
                "params" =>
                    Dict{String,Any}("policy" => policy_d, "simulation" => sim_d),
            ),
        )
        e = CompositeException()
        Engines.__build_engine!(d, e)
        @test length(e) == 0
        @test d["engine"] isa Engines.SDDPEngine
        @test d["engine"].policy.parallel_scheme isa Engines.Asynchronous
    end

    @testset "generate-parallel-scheme-returns-sddp-type" begin
        result = @test_warn r"Asynchronous parallel scheme requested" begin
            Engines.generate_parallel_scheme(Engines.Asynchronous())
        end
        @test result isa SDDP.Asynchronous
    end

    @testset "asynchronous-warning-when-no-workers" begin
        @test Distributed.nprocs() == 1
        @test_warn r"Asynchronous parallel scheme requested" begin
            Engines.generate_parallel_scheme(Engines.Asynchronous())
        end
    end
end
