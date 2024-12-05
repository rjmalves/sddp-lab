import SDDPlab: Utils

@testset "stochasticprocess-utils" begin
    @testset "node2season" begin
        init_1 = [Utils.__node2season(i, 4, 1) for i in 1:8]
        @test all(init_1 .== [1,2,3,4,1,2,3,4])
        
        init_2 = [Utils.__node2season(i, 4, 2) for i in 1:8]
        @test all(init_2 .== [2,3,4,1,2,3,4,1])
    end
end