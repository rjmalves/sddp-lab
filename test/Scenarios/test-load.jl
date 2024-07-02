import SDDPlab: Scenarios

DETERMINISTIC_LOAD_DICT = Dict{String,Any}(
    "values" => [Dict{String,Any}("bus_id" => 1, "stage_index" => 1, "value" => 100.0)]
)

@testset "scenarios-load" begin
    @testset "deterministic-load-valid" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        load = Scenarios.DeterministicLoad(d, e)
        @test typeof(load) === Scenarios.DeterministicLoad
    end

    @testset "deterministic-load-invalid-key" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        pop!(d, "values")
        load = Scenarios.DeterministicLoad(d, e)
        @test load === nothing
    end

    @testset "deterministic-load-invalid-type" begin
        d, e = __renew(DETERMINISTIC_LOAD_DICT)
        d["values"] = nothing
        load = Scenarios.DeterministicLoad(d, e)
        @test load === nothing
    end
end