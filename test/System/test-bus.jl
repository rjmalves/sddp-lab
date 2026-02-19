import SDDPlab: System

DICT = Dict("id" => 1, "name" => "SIN", "deficit_cost" => 1000.0)

@testset "system-bus" begin
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

    # --- Schema boundary tests ---

    @testset "bus-boundary-id-zero-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 0)
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-boundary-id-one-passes" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", 1)
        bus = System.Bus(d, e)
        @test typeof(bus) === System.Bus
        @test length(e) == 0
    end

    @testset "bus-boundary-id-negative-fails" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "id", -1)
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-invalid-deficit-cost-zero" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "deficit_cost", 0.0)
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-invalid-deficit-cost-negative" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "deficit_cost", -100.0)
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-invalid-name-empty" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "")
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-invalid-name-special-chars" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "bus@#\$!")
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-valid-name-with-spaces-and-hyphens" begin
        d, e = __renew(DICT)
        d = __modif_key(d, "name", "South East-1")
        bus = System.Bus(d, e)
        @test typeof(bus) === System.Bus
    end

    @testset "bus-missing-deficit-cost" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "deficit_cost")
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end

    @testset "bus-missing-id" begin
        d, e = __renew(DICT)
        d = __remove_key(d, "id")
        bus = System.Bus(d, e)
        @test bus === nothing
        @test length(e) > 0
    end
end
