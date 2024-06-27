import SDDPlab: Algorithm

using Dates

DICT = convert(Dict{String,Any}, Dict("discount_rate" => 0.05))

@testset "algorithm-scenario-graph" begin
    @testset "regular-scenario-graph-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.RegularScenarioGraph(d, e)) ===
            Algorithm.RegularScenarioGraph
    end

    @testset "regular-scenario-graph-invalid-discount-rate" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "discount_rate", -0.05)
        @test Algorithm.RegularScenarioGraph(d, e) === nothing
    end
end