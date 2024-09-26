import SDDPlab: Resources

DICT = Dict{String,Any}("solver" => Dict("kind" => "CLP", "params" => Dict()))

@testset "resources-resourcesdata" begin
    @testset "resourcesdata-valid-from-file" begin
        cd(example_data_dir)
        e = CompositeException()
        s = Resources.ResourcesData("resources.jsonc", e)
        @test typeof(s) === Resources.ResourcesData
    end
    @testset "resourcesdata-valid" begin
        d, e = __renew(DICT)
        @test typeof(Resources.ResourcesData(d, e)) === Resources.ResourcesData
    end
    @testset "resourcesdata-nonexisting-key" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "solver")
        @test Resources.ResourcesData(d, e) === nothing
    end
    @testset "resourcesdata-invalid-kind" begin
        d_solver = __modif_key(DICT["solver"], "kind", "invalidkind")
        d = Dict("solver" => d_solver)
        d, e = __renew(convert(Dict{String,Any}, d))
        @test Resources.ResourcesData(d, e) === nothing
    end
end