using SDDPlab: SDDPlab
using Suppressor

@testset "main" begin
    @testset "main_success" begin
        e = CompositeException()
        cd(example_dir)
        using GLPK
        # @suppress begin
        SDDPlab.main(; e = e)
        # end
        @test length(e) == 0
    end
end