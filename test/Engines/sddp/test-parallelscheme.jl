import SDDPlab: Engines

SERIAL_DICT = convert(Dict{String,Any}, Dict("kind" => "Serial", "params" => Dict()))
ASYNCHRONOUS_DICT = convert(
    Dict{String,Any}, Dict("kind" => "Asynchronous", "params" => Dict())
)

@testset "engines-sddp-parallelscheme" begin
    @testset "serial-valid" begin
        d, e = __renew(SERIAL_DICT)
        @test typeof(Engines.Serial(d, e)) === Engines.Serial
    end

    @testset "asynchronous-valid" begin
        d, e = __renew(ASYNCHRONOUS_DICT)
        @test typeof(Engines.Asynchronous(d, e)) === Engines.Asynchronous
    end
end