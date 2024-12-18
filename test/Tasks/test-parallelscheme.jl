import SDDPlab: Tasks

SERIAL_DICT = convert(Dict{String,Any}, Dict("kind" => "Serial", "params" => Dict()))
ASYNCHRONOUS_DICT = convert(
    Dict{String,Any}, Dict("kind" => "Asynchronous", "params" => Dict())
)

@testset "tasks-parallelscheme" begin
    @testset "serial-valid" begin
        d, e = __renew(SERIAL_DICT)
        @test typeof(Tasks.Serial(d, e)) === Tasks.Serial
    end

    @testset "asynchronous-valid" begin
        d, e = __renew(ASYNCHRONOUS_DICT)
        @test typeof(Tasks.Asynchronous(d, e)) === Tasks.Asynchronous
    end
end