import SDDPlab: Tasks

using Dates

EXPECTATION_DICT = convert(Dict{String,Any}, Dict())
WORSTCASE_DICT = convert(Dict{String,Any}, Dict())
AVAR_DICT = convert(Dict{String,Any}, Dict("alpha" => 0.5))
CVAR_DICT = convert(Dict{String,Any}, Dict("alpha" => 0.2, "lambda" => 0.5))

@testset "tasks-risk-measure" begin
    @testset "expectation-valid" begin
        d, e = __renew(EXPECTATION_DICT)
        @test typeof(Tasks.Expectation(d, e)) === Tasks.Expectation
    end

    @testset "worstcase-valid" begin
        d, e = __renew(WORSTCASE_DICT)
        @test typeof(Tasks.WorstCase(d, e)) === Tasks.WorstCase
    end

    @testset "avar-valid" begin
        d, e = __renew(AVAR_DICT)
        @test typeof(Tasks.AVaR(d, e)) === Tasks.AVaR
    end

    @testset "avar-invalid-alpha" begin
        d, e = __renew(AVAR_DICT)
        d = __modif_key(d, "alpha", -0.1)
        @test Tasks.AVaR(d, e) === nothing
    end

    @testset "cvar-valid" begin
        d, e = __renew(CVAR_DICT)
        @test typeof(Tasks.CVaR(d, e)) === Tasks.CVaR
    end

    @testset "cvar-invalid-alpha" begin
        d, e = __renew(CVAR_DICT)
        d = __modif_key(d, "alpha", -0.1)
        @test Tasks.CVaR(d, e) === nothing
    end

    @testset "cvar-invalid-lambda" begin
        d, e = __renew(CVAR_DICT)
        d = __modif_key(d, "lambda", 1.1)
        @test Tasks.CVaR(d, e) === nothing
    end
end