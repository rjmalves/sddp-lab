using SDDPlab: SDDPlab

@testset "outputs" begin
    @testset "read_validate_outputs!" begin
        e = CompositeException()
        cd(example_dir)
        d = SDDPlab.read_validate_entrypoint!("main.jsonc", e)
        outputs = SDDPlab.read_validate_outputs!(d["outputs"], e)
        @test typeof(outputs) === SDDPlab.Outputs
    end
end