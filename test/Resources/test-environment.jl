import SDDPlab: Resources

DICT = Dict{String,Any}("solver" => Dict("kind" => "CLP", "params" => Dict()))

@testset "resources-environment" begin
    @testset "environment-valid-from-file" begin
        cd(example_data_dir)
        e = CompositeException()
        s = Resources.Environment("resources.jsonc", e)
        @test typeof(s) === Resources.Environment
    end
    @testset "environment-valid" begin
        d, e = __renew(DICT)
        @test typeof(Resources.Environment(d, e)) === Resources.Environment
    end
    @testset "environment-nonexisting-key" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "solver")
        @test Resources.Environment(d, e) === nothing
    end
    @testset "environment-invalid-kind" begin
        d_solver = __modif_key(DICT["solver"], "kind", "invalidkind")
        d = Dict("solver" => d_solver)
        d, e = __renew(convert(Dict{String,Any}, d))
        @test Resources.Environment(d, e) === nothing
    end
end