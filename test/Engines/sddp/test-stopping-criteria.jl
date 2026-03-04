import SDDPlab: Engines

using Dates

ITERATION_LIMIT_DICT = convert(Dict{String,Any}, Dict("num_iterations" => 5))

TIME_LIMIT_DICT = convert(Dict{String,Any}, Dict("time_seconds" => 5))

LOWER_BOUND_STABILITY_DICT = convert(
    Dict{String,Any}, Dict("threshold" => 0.05, "num_iterations" => 5)
)

STATISTICAL_DICT = convert(
    Dict{String,Any},
    Dict("num_replications" => 100, "iteration_period" => 10, "z_score" => 1.96),
)

SIMULATION_STOPPING_DICT = convert(
    Dict{String,Any}, Dict("replications" => 100, "period" => 5)
)

FIRST_STAGE_STOPPING_DICT = convert(
    Dict{String,Any}, Dict("atol" => 1e-3, "iterations" => 5)
)

STOPPING_CHAIN_DICT = Dict{String,Any}(
    "rules" => [
        Dict{String,Any}(
            "kind" => "IterationLimit",
            "params" => Dict{String,Any}("num_iterations" => 100),
        ),
        Dict{String,Any}(
            "kind" => "LowerBoundStability",
            "params" => Dict{String,Any}("threshold" => 0.05, "num_iterations" => 10),
        ),
    ],
)

@testset "engines-sddp-stopping-criteria" begin
    @testset "iteration-limit-valid" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        @test typeof(Engines.IterationLimit(d, e)) === Engines.IterationLimit
    end

    @testset "time-limit-valid" begin
        d, e = __renew(TIME_LIMIT_DICT)
        @test typeof(Engines.TimeLimit(d, e)) === Engines.TimeLimit
    end

    @testset "lower-bound-stability-valid" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        @test typeof(Engines.LowerBoundStability(d, e)) === Engines.LowerBoundStability
    end

    @testset "iteration-limit-invalid-num_iterations" begin
        d, e = __renew(ITERATION_LIMIT_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Engines.IterationLimit(d, e) === nothing
    end

    @testset "time-limit-invalid-time_seconds" begin
        d, e = __renew(TIME_LIMIT_DICT)
        d = __modif_key(d, "time_seconds", 0)
        @test Engines.TimeLimit(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-threshold" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "threshold", -0.05)
        @test Engines.LowerBoundStability(d, e) === nothing
    end

    @testset "lower-bound-stability-invalid-num_iterations" begin
        d, e = __renew(LOWER_BOUND_STABILITY_DICT)
        d = __modif_key(d, "num_iterations", 0)
        @test Engines.LowerBoundStability(d, e) === nothing
    end

    @testset "statistical-valid" begin
        d, e = __renew(STATISTICAL_DICT)
        result = Engines.Statistical(d, e)
        @test typeof(result) === Engines.Statistical
        @test result.num_replications == 100
        @test result.iteration_period == 10
        @test result.z_score == 1.96
    end

    @testset "statistical-invalid-replications" begin
        d, e = __renew(STATISTICAL_DICT)
        d = __modif_key(d, "num_replications", 0)
        @test Engines.Statistical(d, e) === nothing
    end

    @testset "statistical-invalid-iteration_period" begin
        d, e = __renew(STATISTICAL_DICT)
        d = __modif_key(d, "iteration_period", 0)
        @test Engines.Statistical(d, e) === nothing
    end

    @testset "statistical-invalid-z_score" begin
        d, e = __renew(STATISTICAL_DICT)
        d = __modif_key(d, "z_score", -1.0)
        @test Engines.Statistical(d, e) === nothing
    end

    @testset "simulation-stopping-valid" begin
        d, e = __renew(SIMULATION_STOPPING_DICT)
        result = Engines.SimulationStopping(d, e)
        @test typeof(result) === Engines.SimulationStopping
        @test result.replications == 100
        @test result.period == 5
    end

    @testset "simulation-stopping-invalid-replications" begin
        d, e = __renew(SIMULATION_STOPPING_DICT)
        d = __modif_key(d, "replications", 0)
        @test Engines.SimulationStopping(d, e) === nothing
    end

    @testset "simulation-stopping-invalid-period" begin
        d, e = __renew(SIMULATION_STOPPING_DICT)
        d = __modif_key(d, "period", -1)
        @test Engines.SimulationStopping(d, e) === nothing
    end

    @testset "first-stage-stopping-valid" begin
        d, e = __renew(FIRST_STAGE_STOPPING_DICT)
        result = Engines.FirstStageStopping(d, e)
        @test typeof(result) === Engines.FirstStageStopping
        @test result.atol == 1e-3
        @test result.iterations == 5
    end

    @testset "first-stage-stopping-invalid-atol" begin
        d, e = __renew(FIRST_STAGE_STOPPING_DICT)
        d = __modif_key(d, "atol", -0.01)
        @test Engines.FirstStageStopping(d, e) === nothing
    end

    @testset "first-stage-stopping-invalid-iterations" begin
        d, e = __renew(FIRST_STAGE_STOPPING_DICT)
        d = __modif_key(d, "iterations", 0)
        @test Engines.FirstStageStopping(d, e) === nothing
    end

    @testset "stopping-chain-valid" begin
        d = deepcopy(STOPPING_CHAIN_DICT)
        e = CompositeException()
        result = Engines.StoppingChain(d, e)
        @test typeof(result) === Engines.StoppingChain
        @test length(result.rules) == 2
        @test typeof(result.rules[1]) === Engines.IterationLimit
        @test typeof(result.rules[2]) === Engines.LowerBoundStability
    end

    @testset "stopping-chain-empty-rules" begin
        d = Dict{String,Any}("rules" => Any[])
        e = CompositeException()
        @test Engines.StoppingChain(d, e) === nothing
        @test length(e) > 0
    end

    @testset "stopping-chain-missing-rules" begin
        d = Dict{String,Any}()
        e = CompositeException()
        @test Engines.StoppingChain(d, e) === nothing
        @test length(e) > 0
    end

    @testset "stopping-chain-invalid-inner-rule" begin
        d = Dict{String,Any}(
            "rules" => [
                Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 0),
                ),
            ],
        )
        e = CompositeException()
        @test Engines.StoppingChain(d, e) === nothing
    end
end
