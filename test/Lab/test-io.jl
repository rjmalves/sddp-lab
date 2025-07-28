import SDDPlab: Lab

using CSV
using Parquet

@testset "lab-io" begin
    @testset "lab-io-csvformat" begin
        format = Lab.CSVFormat()
        @test Lab.get_reader(format) === CSV.read
        @test Lab.get_writer(format) === CSV.write
        @test Lab.get_extension(format) === ".csv"
    end
    @testset "lab-io-parquetformat" begin
        format = Lab.ParquetFormat()
        @test Lab.get_reader(format) === Parquet.read_parquet
        @test Lab.get_writer(format) === Parquet.write_parquet
        @test Lab.get_extension(format) === ".parquet"
    end
end