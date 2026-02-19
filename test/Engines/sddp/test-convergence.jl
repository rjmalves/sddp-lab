import SDDPlab: Engines

using Dates

DICT = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 100,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "LowerBoundStability",
        "params" => Dict{String,Any}("threshold" => 0.05, "num_iterations" => 5),
    ),
)

DICT_MULTI = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 100,
    "stopping_criteria" => [
        Dict{String,Any}(
            "kind" => "IterationLimit",
            "params" => Dict{String,Any}("num_iterations" => 50),
        ),
        Dict{String,Any}(
            "kind" => "LowerBoundStability",
            "params" => Dict{String,Any}("threshold" => 0.05, "num_iterations" => 5),
        ),
    ],
)

DICT_WITH_CHAIN = Dict{String,Any}(
    "min_iterations" => 10,
    "max_iterations" => 200,
    "stopping_criteria" => Dict{String,Any}(
        "kind" => "StoppingChain",
        "params" => Dict{String,Any}(
            "rules" => [
                Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 100),
                ),
                Dict{String,Any}(
                    "kind" => "LowerBoundStability",
                    "params" => Dict{String,Any}(
                        "threshold" => 0.05, "num_iterations" => 10
                    ),
                ),
            ],
        ),
    ),
)

@testset "engines-sddp-convergence" begin
    @testset "convergence-valid" begin
        d, e = __renew(DICT)
        @test typeof(Engines.Convergence(d, e)) === Engines.Convergence
    end

    @testset "convergence-invalid-min_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-max_iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", -10)
        d = __modif_key(d, "max_iterations", -5)
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "max_iterations", 1)
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-invalid-stopping_criteria" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stopping_criteria",
            Dict(
                "kind" => "LowerBoundStability",
                "params" => Dict("threshold" => -0.05, "num_iterations" => 5),
            ),
        )
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-missing-stopping-criteria" begin
        d, e = __renew(DICT)
        delete!(d, "stopping_criteria")
        @test Engines.Convergence(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convergence-unrecognized-stopping-criteria-kind" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stopping_criteria",
            Dict("kind" => "UnknownCriteria", "params" => Dict{String,Any}()),
        )
        @test Engines.Convergence(d, e) === nothing
        @test length(e) > 0
    end

    @testset "convergence-equal-min-max-iterations" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "min_iterations", 50)
        d = __modif_key(d, "max_iterations", 50)
        conv = Engines.Convergence(d, e)
        @test typeof(conv) === Engines.Convergence
    end

    @testset "convergence-single-stopping-criteria-is-vector" begin
        d = deepcopy(DICT)
        e = CompositeException()
        conv = Engines.Convergence(d, e)
        @test typeof(conv) === Engines.Convergence
        sc = Engines.get_stopping_criteria(conv)
        @test sc isa Vector{Engines.StoppingCriteria}
        @test length(sc) == 1
        @test typeof(sc[1]) === Engines.LowerBoundStability
    end

    @testset "convergence-multiple-stopping-criteria" begin
        d = deepcopy(DICT_MULTI)
        e = CompositeException()
        conv = Engines.Convergence(d, e)
        @test typeof(conv) === Engines.Convergence
        sc = Engines.get_stopping_criteria(conv)
        @test sc isa Vector{Engines.StoppingCriteria}
        @test length(sc) == 2
        @test typeof(sc[1]) === Engines.IterationLimit
        @test typeof(sc[2]) === Engines.LowerBoundStability
    end

    @testset "convergence-with-stopping-chain" begin
        d = deepcopy(DICT_WITH_CHAIN)
        e = CompositeException()
        conv = Engines.Convergence(d, e)
        @test typeof(conv) === Engines.Convergence
        sc = Engines.get_stopping_criteria(conv)
        @test sc isa Vector{Engines.StoppingCriteria}
        @test length(sc) == 1
        @test typeof(sc[1]) === Engines.StoppingChain
        chain = sc[1]::Engines.StoppingChain
        @test length(chain.rules) == 2
        @test typeof(chain.rules[1]) === Engines.IterationLimit
        @test typeof(chain.rules[2]) === Engines.LowerBoundStability
    end

    @testset "convergence-multiple-criteria-invalid-inner" begin
        d = Dict{String,Any}(
            "min_iterations" => 10,
            "max_iterations" => 100,
            "stopping_criteria" => [
                Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 0),
                ),
                Dict{String,Any}(
                    "kind" => "TimeLimit",
                    "params" => Dict{String,Any}("time_seconds" => 60),
                ),
            ],
        )
        e = CompositeException()
        @test Engines.Convergence(d, e) === nothing
    end

    @testset "convergence-empty-stopping-criteria-array" begin
        d = Dict{String,Any}(
            "min_iterations" => 10, "max_iterations" => 100, "stopping_criteria" => Any[]
        )
        e = CompositeException()
        @test Engines.Convergence(d, e) === nothing
        @test length(e) > 0
    end
end
