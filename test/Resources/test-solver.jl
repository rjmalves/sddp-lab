import SDDPlab: Resources
import GLPK: Optimizer

DICT = Dict("name" => "CLP", "params" => Dict())

@testset "resources-solver" begin
    @testset "clp-valid" begin
        d, e = __renew(DICT)
        @test typeof(Resources.CLP(d, e)) === Resources.CLP
    end

    @testset "glpk-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "GLPK")
        @test typeof(Resources.GLPK(d, e)) === Resources.GLPK
    end

    @testset "highs-valid" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "HiGHS")
        @test typeof(Resources.HiGHS(d, e)) === Resources.HiGHS
    end

    @testset "glpk-generate-optimizer" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "GLPK")
        solver = Resources.GLPK(d, e)
        @test Resources.generate_optimizer(solver) === Optimizer
    end
end