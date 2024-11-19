import SDDPlab: Tasks

RESULT_DICT = convert(
    Dict{String,Any},
    Dict(
        "path" => ".",
        "save" => true,
        "format" => Dict("kind" => "AnyFormat", "params" => Dict()),
    ),
)

ECHO_DICT = convert(Dict{String,Any}, Dict("results" => RESULT_DICT))

POLICY_DICT = convert(
    Dict{String,Any},
    Dict(
        "results" => Dict(
            "path" => ".",
            "save" => true,
            "format" => Dict("kind" => "ParquetFormat", "params" => Dict()),
        ),
        "convergence" => Dict(
            "min_iterations" => 10,
            "max_iterations" => 100,
            "stopping_criteria" => Dict(
                "kind" => "LowerBoundStability",
                "params" => Dict("threshold" => 0.05, "num_iterations" => 5),
            ),
        ),
        "risk_measure" => Dict("kind" => "Expectation", "params" => Dict()),
        "parallel_scheme" => Dict("kind" => "Serial", "params" => Dict()),
    ),
)

POLICY_PATH_DICT = convert(
    Dict{String,Any},
    Dict(
        "path" => ".",
        "load" => true,
        "format" => Dict("kind" => "AnyFormat", "params" => Dict()),
    ),
)

SIMULATION_DICT = convert(
    Dict{String,Any},
    Dict(
        "num_simulated_series" => 500,
        "policy" => POLICY_PATH_DICT,
        "results" => RESULT_DICT,
        "parallel_scheme" => Dict("kind" => "Serial", "params" => Dict()),
    ),
)

@testset "tasks-taskdefinition" begin
    @testset "taskdefinition-echo-valid" begin
        d, e = __renew(ECHO_DICT)
        @test typeof(Tasks.Echo(d, e)) === Tasks.Echo
    end

    @testset "taskdefinition-policy-valid" begin
        d, e = __renew(POLICY_DICT)
        @test typeof(Tasks.Policy(d, e)) === Tasks.Policy
    end

    # @testset "taskdefinition-simulation-valid" begin
    #     d, e = __renew(SIMULATION_DICT)
    #     @test typeof(Tasks.Simulation(d, e)) === Tasks.Simulation
    # end
end