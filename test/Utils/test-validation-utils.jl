import SDDPlab: Utils

using DataFrames

DICT = Dict("a" => 1, "b" => "string", "c" => [[1, 2], [3, 4]])

@testset "validation-utils" begin
    @testset "validate_keys" begin
        d, e = __renew(DICT)
        @test Utils.__validate_keys!(d, ["a", "b", "c"], e)

        d = __remove_key(d, "a")
        valid = Utils.__validate_keys!(d, ["a", "b", "c"], e)
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Key 'a' not found in dictionary"

        # chaves extras sao permitidas, contanto que todas as necessarias existam
        d, e = __renew(DICT)
        d["d"] = 2
        valid = Utils.__validate_keys!(d, ["a", "b", "c"], e)
        @test valid == true
    end

    @testset "validate_key_length" begin
        d, e = __renew(DICT)
        @test Utils.__validate_key_lengths!(d, ["a", "b", "c"], [1, 6, 2], e)

        valid = Utils.__validate_key_lengths!(d, ["a", "b", "c"], [1, 5, 2], e)
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Key 'b' has length =/= 5"
    end

    @testset "validate_key_types" begin
        d, e = __renew(DICT)
        @test Utils.__validate_key_types!(
            d, ["a", "b", "c"], [Int, String, Vector{Vector{Int}}], e
        )

        valid = Utils.__validate_key_types!(
            d, ["a", "b", "c"], [Int, String, Vector{Vector{Float64}}], e
        )
        @test valid == true
        @test d["c"][1][1] == 1.0

        valid = Utils.__validate_key_types!(
            d, ["a", "b", "c"], [String, String, Vector{Vector{Float64}}], e
        )
        @test valid == true
        @test d["a"] == "1"

        d, e = __renew(DICT)
        valid = Utils.__validate_key_types!(
            d, ["a", "b", "c"], [Int, String, Matrix{Int}], e
        )
        @test valid == true
        @test d["c"] == [1 2; 3 4]

        d, e = __renew(DICT)
        valid = Utils.__validate_key_types!(d, ["a", "b", "c"], [Int, String, Int], e)
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg ==
            "Key 'c' ([[1, 2], [3, 4]]) can't be converted to Int64"
    end

    @testset "validate_file" begin
        cd(example_dir)

        e = CompositeException()
        filename = "main.jsonc"
        @test Utils.__validate_file!(filename, e) == true

        filename = "non-existent-file"
        @test Utils.__validate_file!(filename, e) == false
        @test e.exceptions[1].msg == "$filename not found!"
    end

    @testset "validate_directory" begin
        cd(example_dir)

        e = CompositeException()
        dirname = "data"
        @test Utils.__validate_directory!(dirname, e) == true

        dirname = "non-existent-file"
        @test Utils.__validate_directory!(dirname, e) == false
        @test e.exceptions[1].msg == "$dirname not found!"
    end

    @testset "dataframe_to_dict" begin
        df = DataFrame(; a = [1, 2], b = ["a", "b"])
        d = Utils.__dataframe_to_dict(df)
        @test d == [Dict("a" => 1, "b" => "a"), Dict("a" => 2, "b" => "b")]
    end

    @testset "validate_columns_in_dataframe" begin
        df = DataFrame(; a = [1, 2], b = ["a", "b"])
        e = CompositeException()
        @test Utils.__validate_columns_in_dataframe!(df, ["a", "b"], e) == true

        df = DataFrame(; a = [1, 2], b = ["a", "b"])
        df_columns = names(df)
        valid = Utils.__validate_columns_in_dataframe!(df, ["a", "b", "c"], e)
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Column c not found in DataFrame ($df_columns)"
    end

    @testset "validate_column_types_in_dataframe" begin
        df = DataFrame(; a = [1, 2], b = ["a", "b"])
        e = CompositeException()
        valid = Utils.__validate_column_types_in_dataframe!(
            df, ["a", "b"], [Integer, String], e
        )
        @test valid == true

        df = DataFrame(; a = [1, 2], b = ["a", "b"])
        valid = Utils.__validate_column_types_in_dataframe!(
            df, ["a", "b"], [Integer, Integer], e
        )
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Column b (String) not of type (Integer)"
    end

    @testset "validate_required_default_values" begin
        default_values = Dict{String,Any}("a" => 1, "b" => 2)
        columns_requiring_default_values = ["b"]
        columns_data_types = [Integer]
        df = DataFrame(; a = [1, 2], b = [2, nothing])

        e = CompositeException()
        valid = Utils.__validate_required_default_values!(
            default_values, columns_requiring_default_values, columns_data_types, df, e
        )
        @test valid == true

        default_values = Dict{String,Any}("a" => 1)
        valid = Utils.__validate_required_default_values!(
            default_values, columns_requiring_default_values, columns_data_types, df, e
        )
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Key 'b' not found in dictionary"
    end
end