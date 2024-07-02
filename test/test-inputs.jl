using SDDPlab: SDDPlab

@testset "inputs" begin
    @testset "read_validate_entrypoint" begin
        e = CompositeException()
        cd(example_dir)
        d = SDDPlab.read_validate_entrypoint!("main.jsonc", e)
        @test typeof(d) === Dict{String,Any}
    end

    @testset "read_validate_inputs!" begin
        e = CompositeException()
        cd(example_dir)
        d = SDDPlab.read_validate_entrypoint!("main.jsonc", e)
        inputs = SDDPlab.read_validate_inputs!(d["inputs"], e)
        @test typeof(inputs) === SDDPlab.Inputs
    end
end