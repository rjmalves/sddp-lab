import SDDPlab: Algorithm

using Dates

DICT = Dict(
    "index" => 1, "start_date" => DateTime(2024, 1, 1), "end_date" => DateTime(2024, 2, 1)
)

@testset "algorithm-stage" begin
    @testset "stage-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.Stage(d, e)) === Algorithm.Stage
    end

    @testset "stage-invalid-index" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "index", 0)
        @test Algorithm.Stage(d, e) === nothing
    end

    @testset "stage-invalid-dates" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "end_date", DateTime(2024, 1, 1))
        @test Algorithm.Stage(d, e) === nothing
    end
end