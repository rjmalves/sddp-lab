import SDDPlab: Tasks

DICT = convert(
    Dict{String,Any},
    Dict(
        "path" => ".",
        "save" => true,
        "format" => Dict("kind" => "AnyFormat", "params" => Dict()),
    ),
)

@testset "tasks-taskresults" begin
    @testset "taskresults-valid" begin
        d, e = __renew(DICT)
        @test typeof(Tasks.TaskResults(d, e)) === Tasks.TaskResults
    end

    # TODO - currently the 'path' key is not being validated
    # @testset "results-invalid-path" begin
    #     d, e = __renew(DICT)
    #     d = __modif_key(d, "path", "/notexistent")
    #     @test Tasks.Results(d, e) === nothing
    # end

    # TODO - currently the 'save' key is not being validated
    # @testset "results-invalid-save" begin
    #     d, e = __renew(DICT)
    #     d = __modif_key(d, "save", 0)
    #     @test Tasks.Results(d, e) === nothing
    # end
end