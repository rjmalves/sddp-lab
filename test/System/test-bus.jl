import SDDPlab: System

DICT = Dict("id" => 1, "name" => "SIN", "deficit_cost" => 1000.0)

@testset "system" begin
    @testset "bus-valid" begin
        d, e = __renew(DICT)
        @test typeof(System.Bus(d, e)) === System.Bus
    end

    @testset "bus-invalid-id" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        @test System.Bus(d, e) === nothing
    end

    @testset "bus-nonexistent-name" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "name")
        @test System.Bus(d, e) === nothing
    end
end