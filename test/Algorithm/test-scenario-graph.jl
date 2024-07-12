import SDDPlab: Algorithm

using Dates

REGULAR_DICT = convert(Dict{String,Any}, Dict("discount_rate" => 0.05))

CYCLIC_DICT = convert(
    Dict{String,Any},
    Dict(
        "discount_rate" => 0.05, "cycle_length" => 3, "cycle_stage" => 2, "max_depth" => 5
    ),
)

@testset "algorithm-scenario-graph" begin
    @testset "regular-scenario-graph-valid" begin
        d, e = __renew(REGULAR_DICT)
        @test typeof(Algorithm.RegularScenarioGraph(d, e)) ===
            Algorithm.RegularScenarioGraph
    end

    @testset "regular-scenario-graph-invalid-discount-rate" begin
        d, e = __renew(REGULAR_DICT)
        d = __modif_key(d, "discount_rate", -0.05)
        @test Algorithm.RegularScenarioGraph(d, e) === nothing
    end

    @testset "cyclic-scenario-graph-valid" begin
        d, e = __renew(CYCLIC_DICT)
        @test typeof(Algorithm.CyclicScenarioGraph(d, e)) === Algorithm.CyclicScenarioGraph
    end

    @testset "cyclic-scenario-graph-invalid-discount-rate" begin
        d, e = __renew(CYCLIC_DICT)
        d = __modif_key(d, "discount_rate", 1.00)
        @test Algorithm.CyclicScenarioGraph(d, e) === nothing
    end

    @testset "cyclic-scenario-graph-invalid-cycle-length" begin
        d, e = __renew(CYCLIC_DICT)
        d = __modif_key(d, "cycle_length", 0)
        @test Algorithm.CyclicScenarioGraph(d, e) === nothing
    end

    @testset "cyclic-scenario-graph-invalid-cycle-stage" begin
        d, e = __renew(CYCLIC_DICT)
        d = __modif_key(d, "cycle_stage", 0)
        @test Algorithm.CyclicScenarioGraph(d, e) === nothing
    end

    @testset "cyclic-scenario-graph-invalid-max-depth" begin
        d, e = __renew(CYCLIC_DICT)
        d = __modif_key(d, "max_depth", 3)
        @test Algorithm.CyclicScenarioGraph(d, e) === nothing
    end
end