import SDDPlab: Utils

using DataFrames

@testset "reading-utils" begin
    @testset "read_jsonc" begin
        cd(example_dir)
        e = CompositeException()
        d = Utils.read_jsonc("main.jsonc", e)
        @test haskey(d, "inputs")
    end

    @testset "read_csv" begin
        cd(example_data_dir)
        e = CompositeException()
        df = Utils.read_csv("buses.csv", e)
        @test names(df) == ["id", "name", "deficit_cost"]
    end

    @testset "get_dataframe_columns_for_default_value_fill" begin
        df = DataFrame(; a = [1, 2], b = [2, missing])
        columns, data_types = Utils.__get_dataframe_columns_for_default_value_fill(df)
        @test columns[1] == "b"
        @test data_types[1] <: Integer
    end

    @testset "__fill_default_values!" begin
        df = DataFrame(; a = [1, 2], b = [2, missing])
        default_values = Dict{String,Any}("b" => 3)
        Utils.__fill_default_values!(df, default_values)
        columns, data_types = Utils.__get_dataframe_columns_for_default_value_fill(df)
        @test length(columns) == 0
    end
end