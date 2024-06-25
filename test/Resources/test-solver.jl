import SDDPlab: Resources

DICT = Dict("name" => "CLP", "params" => Dict())

@testset "resources-solver" begin
    @testset "clp-valid" begin
        d, e = __renew(DICT)
        @test typeof(Resources.CLP(d, e)) === Resources.CLP
    end
    @testset "clp-invalid-name" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "GLPK")
        # TODO
        # @test Resources.CLP(d, e) === nothing
    end
end