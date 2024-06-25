import SDDPlab: Algorithm

using Dates

DICT = convert(Dict{String,Any}, Dict("discount_rate" => 0.05))

@testset "algorithm-policy-graph" begin
    @testset "regular-policy-graph-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.RegularPolicyGraph(d, e)) === Algorithm.RegularPolicyGraph
    end

    @testset "regular-policy-graph-invalid-discount-rate" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "discount_rate", -0.05)
        @test Algorithm.RegularPolicyGraph(d, e) === nothing
    end
end