import SDDPlab: Engines
import SDDPlab: System
using HiGHS
using JuMP
using Logging: with_logger, NullLogger

# Helper to build a minimal study silently
function _build_study(example_case::String)
    example_dir = joinpath(@__DIR__, "..", "..", "..", "example", example_case)
    e = CompositeException()
    study = with_logger(NullLogger()) do
        SDDPlab.read_study(example_dir; e = e)
    end
    return study, e
end

@testset "build-optimizations" begin

    @testset "_build_bus_index_map-basic-correctness" begin
        # Construct mock entities with known bus_id assignments to verify map correctness.
        # Bus positions: bus_ids = [10, 20, 30]  (positions 1, 2, 3)
        # Thermals: T1.bus_id=10, T2.bus_id=20, T3.bus_id=10, T4.bus_id=30
        # Expected: map[1] = [1, 3], map[2] = [2], map[3] = [4]

        bus_ids = Integer[10, 20, 30]

        thermals = [
            System.Thermal(1, "T1", 10, 0.0, 100.0, 10.0, Ref(System.Bus(10, "B1", 500.0))),
            System.Thermal(2, "T2", 20, 0.0, 50.0,  20.0, Ref(System.Bus(20, "B2", 500.0))),
            System.Thermal(3, "T3", 10, 0.0, 80.0,  15.0, Ref(System.Bus(10, "B1", 500.0))),
            System.Thermal(4, "T4", 30, 0.0, 40.0,  25.0, Ref(System.Bus(30, "B3", 500.0))),
        ]

        result = Engines._build_bus_index_map(thermals, bus_ids, :bus_id)

        @test haskey(result, 1)
        @test haskey(result, 2)
        @test haskey(result, 3)
        @test sort(result[1]) == [1, 3]
        @test result[2] == [2]
        @test result[3] == [4]
        # Bus position 4 does not exist (no entities mapped there)
        @test !haskey(result, 4)
    end

    @testset "_build_bus_index_map-empty-entities" begin
        bus_ids = Integer[1, 2, 3]
        thermals = System.Thermal[]
        result = Engines._build_bus_index_map(thermals, bus_ids, :bus_id)
        @test isempty(result)
    end

    @testset "_build_bus_index_map-single-entity-single-bus" begin
        bus_ids = Integer[42]
        thermals = [
            System.Thermal(1, "T1", 42, 0.0, 100.0, 10.0, Ref(System.Bus(42, "B1", 500.0)))
        ]
        result = Engines._build_bus_index_map(thermals, bus_ids, :bus_id)
        @test haskey(result, 1)
        @test result[1] == [1]
    end

    @testset "_build_bus_index_map-line-target-bus" begin
        # Verify that :target_bus_id field is accessed correctly
        bus_ids = Integer[1, 2, 3]
        b1 = System.Bus(1, "B1", 500.0)
        b2 = System.Bus(2, "B2", 500.0)
        b3 = System.Bus(3, "B3", 500.0)
        lines = [
            System.Line(1, "L1", 1, 2, 100.0, 0.1, Ref(b1), Ref(b2)),  # target=2
            System.Line(2, "L2", 2, 3, 100.0, 0.1, Ref(b2), Ref(b3)),  # target=3
            System.Line(3, "L3", 1, 2, 80.0,  0.1, Ref(b1), Ref(b2)),  # target=2
        ]
        target_map = Engines._build_bus_index_map(lines, bus_ids, :target_bus_id)

        # target bus 2 (position 2) <- lines 1 and 3
        # target bus 3 (position 3) <- line 2
        # target bus 1 (position 1) <- none
        @test !haskey(target_map, 1)
        @test sort(target_map[2]) == [1, 3]
        @test target_map[3] == [2]
    end

    @testset "_build_bus_index_map-line-source-bus" begin
        bus_ids = Integer[1, 2, 3]
        b1 = System.Bus(1, "B1", 500.0)
        b2 = System.Bus(2, "B2", 500.0)
        b3 = System.Bus(3, "B3", 500.0)
        lines = [
            System.Line(1, "L1", 1, 2, 100.0, 0.1, Ref(b1), Ref(b2)),  # source=1
            System.Line(2, "L2", 2, 3, 100.0, 0.1, Ref(b2), Ref(b3)),  # source=2
            System.Line(3, "L3", 1, 3, 80.0,  0.1, Ref(b1), Ref(b3)),  # source=1
        ]
        source_map = Engines._build_bus_index_map(lines, bus_ids, :source_bus_id)

        # source bus 1 (position 1) <- lines 1 and 3
        # source bus 2 (position 2) <- line 2
        @test sort(source_map[1]) == [1, 3]
        @test source_map[2] == [2]
        @test !haskey(source_map, 3)
    end

    @testset "precomputed-load-balance-equivalence-1dtoy" begin
        study, e = _build_study("1dtoy")
        @test length(e) == 0
        model = with_logger(NullLogger()) do
            SDDPlab.build(study, HiGHS.Optimizer)
        end
        @test model !== nothing

        # Train for a few iterations to confirm the model is mathematically correct
        policy = with_logger(NullLogger()) do
            SDDPlab.train(study, model)
        end
        @test policy !== nothing
    end

    @testset "precomputed-load-balance-equivalence-4ree" begin
        study, e = _build_study("4ree")
        @test length(e) == 0
        model = with_logger(NullLogger()) do
            SDDPlab.build(study, HiGHS.Optimizer)
        end
        @test model !== nothing

        policy = with_logger(NullLogger()) do
            SDDPlab.train(study, model)
        end
        @test policy !== nothing
    end

end
