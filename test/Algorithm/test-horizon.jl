import SDDPlab: Algorithm

using Dates

DICT = convert(
    Dict{String,Any},
    Dict(
        "stages" => [
            Dict(
                "index" => 1,
                "start_date" => DateTime(2024, 1, 1),
                "end_date" => DateTime(2024, 2, 1),
            ),
            Dict(
                "index" => 2,
                "start_date" => DateTime(2024, 2, 1),
                "end_date" => DateTime(2024, 3, 1),
            ),
        ],
    ),
)

@testset "algorithm-horizon" begin
    @testset "explicit-horizon-valid" begin
        d, e = __renew(DICT)
        @test typeof(Algorithm.ExplicitHorizon(d, e)) === Algorithm.ExplicitHorizon
    end

    @testset "explicit-horizon-invalid-indexes" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stages",
            [
                Dict(
                    "index" => 1,
                    "start_date" => DateTime(2024, 1, 1),
                    "end_date" => DateTime(2024, 2, 1),
                ),
                Dict(
                    "index" => 1,
                    "start_date" => DateTime(2024, 2, 1),
                    "end_date" => DateTime(2024, 3, 1),
                ),
            ],
        )
        @test Algorithm.ExplicitHorizon(d, e) === nothing
    end

    @testset "explicit-horizon-invalid-dates" begin
        d, e = __renew(DICT)
        d = __modif_key(
            d,
            "stages",
            [
                Dict(
                    "index" => 1,
                    "start_date" => DateTime(2024, 1, 1),
                    "end_date" => DateTime(2024, 3, 1),
                ),
                Dict(
                    "index" => 2,
                    "start_date" => DateTime(2024, 2, 1),
                    "end_date" => DateTime(2024, 4, 1),
                ),
            ],
        )
        @test Algorithm.ExplicitHorizon(d, e) === nothing
    end
end