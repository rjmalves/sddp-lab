using SDDPlab: SDDPlab

@testset "main" begin
    @testset "main_success" begin
        e = CompositeException()
        cd(example_dir)
        SDDPlab.main()
        @test length(e) == 0
    end
end