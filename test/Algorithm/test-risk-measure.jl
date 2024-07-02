import SDDPlab: Algorithm

using Dates

DICT = convert(Dict{String,Any}, Dict())

@testset "algorithm-risk-measure" begin
    @testset "expectation-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.Expectation(d, e)) === Algorithm.Expectation
    end
end