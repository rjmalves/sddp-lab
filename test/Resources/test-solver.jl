import SDDPlab: Resources
import GLPK: Optimizer
using JuMP

DICT = Dict("kind" => "CLP", "params" => Dict{String,Any}())

@testset "resources-solver" begin
    @testset "clp-valid" begin
        d, e = __renew(DICT)
        @test typeof(Resources.CLP(d["params"], e)) === Resources.CLP
    end

    @testset "glpk-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "GLPK")
        @test typeof(Resources.GLPK(d["params"], e)) === Resources.GLPK
    end

    @testset "highs-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "HIGHS")
        @test typeof(Resources.HiGHS(d["params"], e)) === Resources.HiGHS
    end

    @testset "glpk-generate-optimizer" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "kind", "GLPK")
        solver = Resources.GLPK(d, e)
        # TODO - improve test
        # @test Resources.generate_optimizer(solver) === Optimizer
        @test Resources.generate_optimizer(solver) === MOI.OptimizerWithAttributes{Any,Any}
    end
end