import SDDPlab: Engines

CONVERGENCE_DICT_T = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 128,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "IterationLimit",
        "params" => Dict{String,Any}("num_iterations" => 128),
    ),
)

RISK_MEASURE_DICT_T = Dict{String,Any}(
    "kind" => "CVaR", "params" => Dict{String,Any}("alpha" => 0.2, "lambda" => 0.9)
)

@testset "engines-threaded" begin
    @testset "threaded-parallel-scheme-policy" begin
        policy_d = Dict{String,Any}(
            "convergence" => deepcopy(CONVERGENCE_DICT_T),
            "risk_measure" => deepcopy(RISK_MEASURE_DICT_T),
            "parallel_scheme" => Dict{String,Any}("kind" => "Threaded", "params" => Dict{String,Any}()),
        )
        sim_d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        d = Dict{String,Any}(
            "engine" => Dict{String,Any}(
                "kind" => "SDDPEngine",
                "params" => Dict{String,Any}("policy" => policy_d, "simulation" => sim_d),
            ),
        )
        e = CompositeException()
        Engines.__build_engine!(d, e)
        @test length(e) == 0
        @test d["engine"] isa Engines.SDDPEngine
        @test d["engine"].policy.parallel_scheme isa Engines.Threaded
    end

    @testset "threaded-parallel-scheme-simulation" begin
        policy_d = Dict{String,Any}(
            "convergence" => deepcopy(CONVERGENCE_DICT_T),
            "risk_measure" => deepcopy(RISK_MEASURE_DICT_T),
            "parallel_scheme" => Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        sim_d = Dict{String,Any}(
            "num_simulated_series" => 100,
            "parallel_scheme" => Dict{String,Any}("kind" => "Threaded", "params" => Dict{String,Any}()),
        )
        d = Dict{String,Any}(
            "engine" => Dict{String,Any}(
                "kind" => "SDDPEngine",
                "params" => Dict{String,Any}("policy" => policy_d, "simulation" => sim_d),
            ),
        )
        e = CompositeException()
        Engines.__build_engine!(d, e)
        @test length(e) == 0
        @test d["engine"] isa Engines.SDDPEngine
        @test d["engine"].simulation.parallel_scheme isa Engines.Threaded
    end
end
