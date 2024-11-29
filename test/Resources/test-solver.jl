import SDDPlab: Resources
using JuMP

DICT = Dict("kind" => "CLP", "params" => Dict{String,Any}())

@testset "resources-solver" begin
    @testset "clp-valid" begin
        using Clp
        d, e = __renew(DICT)
        @test typeof(Resources.CLP(d["params"], e)) === Resources.CLP
        d = __modif_key(d, "params", Dict{String,Any}("PrimalTolerance" => 0.1))
        @test typeof(Resources.CLP(d["params"], e)) === Resources.CLP
    end

    @testset "clp-invalid" begin
        using Clp
        d, e = __renew(DICT)
        d = __modif_key(d, "params", Dict{String,Any}("PrimalTolerancee" => 0.1))
        @test Resources.CLP(d["params"], e) === nothing
    end

    @testset "glpk-valid" begin
        using GLPK
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "GLPK")
        @test typeof(Resources.GLPK(d["params"], e)) === Resources.GLPK
        d = __modif_key(d, "params", Dict{String,Any}("tol_int" => 0.1))
        @test typeof(Resources.GLPK(d["params"], e)) === Resources.GLPK
    end

    @testset "glpk-invalid" begin
        using GLPK
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "GLPK")
        d = __modif_key(d, "params", Dict{String,Any}("tol_intt" => 0.1))
        @test Resources.GLPK(d["params"], e) === nothing
    end

    @testset "highs-valid" begin
        using HiGHS
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "HIGHS")
        @test typeof(Resources.HiGHS(d["params"], e)) === Resources.HiGHS
    end

    @testset "glpk-generate-optimizer" begin
        using HiGHS
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "GLPK")
        solver = Resources.GLPK(d["params"], e)
        @test typeof(Resources.generate_optimizer(solver)) === MOI.OptimizerWithAttributes
        d = __modif_key(d, "params", Dict{String,Any}("tol_int" => 0.1))
        solver = Resources.GLPK(d["params"], e)
        @test typeof(Resources.generate_optimizer(solver)) === MOI.OptimizerWithAttributes
    end
end