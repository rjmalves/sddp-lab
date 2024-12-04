import SDDPlab: Tasks

function _create_result_dict_taskdata()::Dict
    RESULT_DICT = convert(
        Dict{String,Any},
        Dict(
            "save" => true,
            "path" => "out/policy",
            "format" => Dict("kind" => "AnyFormat", "params" => Dict()),
        ),
    )
    return RESULT_DICT
end

function _create_policy_params_dict()::Dict
    POLICY_PARAMS_DICT = convert(
        Dict{String,Any},
        Dict(
            "results" => _create_result_dict_taskdata(),
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
    return POLICY_PARAMS_DICT
end

function _create_policy_dict(params_dict::Dict)::Dict
    POLICY_DICT = convert(
        Dict{String,Any}, Dict("kind" => "Policy", "params" => params_dict)
    )
    return POLICY_DICT
end

function _create_simulation_policy_path_dict(
    load::Bool, path::String, format::Dict{String,Any}
)::Dict
    POLICY_PATH_DICT = convert(
        Dict{String,Any}, Dict("load" => load, "path" => path, "format" => format)
    )
    return POLICY_PATH_DICT
end

function _create_simulation_params_dict(policy_dict::Dict)::Dict
    SIMULATION_PARAMS_DICT = convert(
        Dict{String,Any},
        Dict(
            "num_simulated_series" => 500,
            "policy" => policy_dict,
            "results" => _create_result_dict_taskdata(),
            "parallel_scheme" => Dict("kind" => "Serial", "params" => Dict()),
        ),
    )
    return SIMULATION_PARAMS_DICT
end

function _create_simulation_dict(params_dict::Dict)::Dict
    SIMULATION_DICT = convert(
        Dict{String,Any}, Dict("kind" => "Simulation", "params" => params_dict)
    )
    return SIMULATION_DICT
end

# Creating Policy Task dict
POLICY_PARAMS_DICT = _create_policy_params_dict()

# Creating Simulation Task dict
SIMULATION_POLICY_DICT = _create_simulation_policy_path_dict(
    false, "out/policy", Dict("kind" => "AnyFormat", "params" => Dict())
)
SIMULATION_PARAMS_DICT = _create_simulation_params_dict(SIMULATION_POLICY_DICT)

# Creating Tasks dict
TASKS_DICT = convert(
    Dict{String,Any},
    Dict(
        "tasks" => [
            _create_policy_dict(POLICY_PARAMS_DICT),
            _create_simulation_dict(SIMULATION_PARAMS_DICT),
        ],
    ),
)

@testset "task-taskdata" begin
    @testset "task-valid" begin
        d, e = __renew(convert(Dict{String,Any}, TASKS_DICT))
        tasks = Tasks.TasksData(d, e)
        @test typeof(tasks) === Tasks.TasksData
    end
    @testset "task-invalid" begin
        d, e = __renew(convert(Dict{String,Any}, TASKS_DICT))
        d = __modif_key(d, "tasks", Dict())
        tasks = Tasks.TasksData(d, e)
        @test tasks === nothing
    end
    @testset "task-valid-simulation-policy" begin
        d_simulation_policy = _create_simulation_policy_path_dict(
            true, "out/policy", Dict("kind" => "AnyFormat", "params" => Dict())
        )
        d_simulation = _create_simulation_dict(
            _create_simulation_params_dict(d_simulation_policy)
        )
        d_policy = _create_policy_dict(_create_policy_params_dict())
        d_tasks = Dict("tasks" => [d_policy, d_simulation])
        d, e = __renew(convert(Dict{String,Any}, d_tasks))
        tasks = Tasks.TasksData(d, e)
        @test typeof(tasks) === Tasks.TasksData
    end
    @testset "task-invalid-simulation-policy" begin
        d_simulation_policy = _create_simulation_policy_path_dict(
            false, "policy", Dict("kind" => "AnyFormat", "params" => Dict())
        )
        d_simulation = _create_simulation_dict(
            _create_simulation_params_dict(d_simulation_policy)
        )
        d_tasks = Dict("tasks" => [d_simulation])
        d, e = __renew(convert(Dict{String,Any}, d_tasks))
        tasks = Tasks.TasksData(d, e)
        @test tasks === nothing
    end
end
