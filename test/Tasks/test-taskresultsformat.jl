import SDDPlab: Tasks

ANY_DICT = convert(Dict{String,Any}, Dict("kind" => "AnyFormat", "params" => Dict()))
CSV_DICT = convert(Dict{String,Any}, Dict("kind" => "CSVFormat", "params" => Dict()))
PARQUET_DICT = convert(
    Dict{String,Any}, Dict("kind" => "ParquetFormat", "params" => Dict())
)

@testset "tasks-taskresultsformat" begin
    @testset "anyformat-valid" begin
        d, e = __renew(ANY_DICT)
        @test typeof(Tasks.AnyFormat(d, e)) === Tasks.AnyFormat
    end

    @testset "csvformat-valid" begin
        d, e = __renew(ANY_DICT)
        @test typeof(Tasks.CSVFormat(d, e)) === Tasks.CSVFormat
    end

    @testset "parquetformat-valid" begin
        d, e = __renew(ANY_DICT)
        @test typeof(Tasks.ParquetFormat(d, e)) === Tasks.ParquetFormat
    end
end