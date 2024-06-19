import SDDPlab: Utils

DICT = Dict(
    "a" => 1,
    "b" => "string",
    "c" => [[1, 2], [3, 4]]
)

@testset "valid-utils" begin
    
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
        @test Utils.__validate_key_types!(d, ["a", "b", "c"], [Int, String, Vector{Vector{Int}}], e)
        
        valid = Utils.__validate_key_types!(d, ["a", "b", "c"], [Int, String, Vector{Vector{Float64}}], e)
        @test valid == true
        @test d["c"][1][1] == 1.0
        
        valid = Utils.__validate_key_types!(d, ["a", "b", "c"], [String, String, Vector{Vector{Float64}}], e)
        @test valid == true
        @test d["a"] == "1"
        
        d, e = __renew(DICT)
        valid = Utils.__validate_key_types!(d, ["a", "b", "c"], [Int, String, Matrix{Int}], e)
        @test valid == true
        @test d["c"] == [1 2;3 4]
        
        d, e = __renew(DICT)
        valid = Utils.__validate_key_types!(d, ["a", "b", "c"], [Int, String, Int], e)
        @test valid == false
        @test length(e) == 1
        @test e.exceptions[1].msg == "Key 'c' can't be converted to Int64"
    end
    
end