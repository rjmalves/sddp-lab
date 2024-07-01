import SDDPlab: System

BUSES_DICT = [
    Dict("id" => 1, "name" => "SE", "deficit_cost" => 1000.0),
    Dict("id" => 2, "name" => "NE", "deficit_cost" => 1000.0),
]

LINE_DICT = Dict(
    "id" => 1,
    "name" => "SIN",
    "source_bus_id" => 1,
    "target_bus_id" => 2,
    "capacity" => 500.0,
    "exchange_penalty" => 0.0,
)

HYDRO_DICT = Dict(
    "id" => 1,
    "name" => "UHE1",
    "downstream_id" => 0,
    "bus_id" => 1,
    "productivity" => 1.0,
    "initial_storage" => 50.0,
    "min_storage" => 0.0,
    "max_storage" => 100.0,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "spillage_penalty" => 0.01,
)

THERMAL_DICT = Dict(
    "id" => 1,
    "name" => "UTE1",
    "bus_id" => 1,
    "min_generation" => 0.0,
    "max_generation" => 300.0,
    "cost" => 100.0,
)

CFG_DICT = Dict(
    "buses" => Dict{String,Any}("entities" => BUSES_DICT),
    "lines" => Dict{String,Any}("entities" => [LINE_DICT]),
    "hydros" => Dict{String,Any}("entities" => [HYDRO_DICT]),
    "thermals" => Dict{String,Any}("entities" => [THERMAL_DICT]),
)

@testset "system-configuration" begin
    @testset "configuration-valid" begin
        d, e = __renew(convert(Dict{String,Any}, CFG_DICT))
        cfg = System.Configuration(d, e)
        @test typeof(cfg) === System.Configuration
    end
    # TODO - testar não construção de Configuration
    @testset "configuration-invalid-id" begin
        d, e = __renew(convert(Dict{String,Any}, CFG_DICT))
        # d = __modif_key(d, "buses", [HYDRO_DICT1])
        # d = __remove_key(d, "thermals")
        # @test System.Configuration(d, e) === nothing
    end

    @testset "configuration-valid-from-file" begin
        d, e = __renew(DICT)

        cd(example_data_dir)
        s = System.Configuration("system.jsonc", e)
        @test typeof(s) === System.Configuration
    end
end