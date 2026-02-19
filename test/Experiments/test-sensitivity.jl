using Test
using SDDPlab
using CSV

_example_dir() = abspath(joinpath(@__DIR__, "..", "..", "example", "1dtoy"))

function _write_sensitivity_jsonc(dir::String, content::String)
    path = joinpath(dir, "sensitivity.jsonc")
    open(path, "w") do io
        write(io, content)
    end
    return path
end

function _minimal_oat_jsonc(
    example_path::String,
    output_dir::String;
    max_iterations::Int = 3,
    num_simulations::Int = 3,
    overwrite::Bool = true,
)
    example_escaped = replace(example_path, "\\" => "/")
    output_escaped  = replace(output_dir,   "\\" => "/")
    return """
    {
        "base_study": "$example_escaped",
        "output_dir": "$output_escaped",
        "mode": "oat",
        "overwrite": $overwrite,
        "base_overrides": {
            "policy": {
                "convergence": {
                    "min_iterations": 1,
                    "max_iterations": $max_iterations,
                    "stopping_criteria": {
                        "kind": "IterationLimit",
                        "params": { "num_iterations": $max_iterations }
                    }
                }
            },
            "simulation": {
                "num_simulated_series": $num_simulations,
                "parallel_scheme": { "kind": "Serial", "params": {} }
            }
        },
        "parameters": [
            {
                "path": "policy.risk_measure",
                "label": "risk_measure",
                "values": [
                    { "kind": "Expectation", "params": {} },
                    { "kind": "AVaR", "params": { "alpha": 0.5 } }
                ]
            }
        ]
    }
    """
end

function _minimal_factorial_jsonc(
    example_path::String,
    output_dir::String;
    max_iterations::Int = 3,
    overwrite::Bool = true,
)
    example_escaped = replace(example_path, "\\" => "/")
    output_escaped  = replace(output_dir,   "\\" => "/")
    return """
    {
        "base_study": "$example_escaped",
        "output_dir": "$output_escaped",
        "mode": "factorial",
        "overwrite": $overwrite,
        "base_overrides": {
            "policy": {
                "convergence": {
                    "min_iterations": 1,
                    "max_iterations": $max_iterations,
                    "stopping_criteria": {
                        "kind": "IterationLimit",
                        "params": { "num_iterations": $max_iterations }
                    }
                }
            },
            "simulation": {
                "num_simulated_series": 2,
                "parallel_scheme": { "kind": "Serial", "params": {} }
            }
        },
        "parameters": [
            {
                "path": "policy.risk_measure",
                "label": "risk_measure",
                "values": [
                    { "kind": "Expectation", "params": {} },
                    { "kind": "AVaR", "params": { "alpha": 0.5 } }
                ]
            },
            {
                "path": "simulation.num_simulated_series",
                "label": "num_simulations",
                "values": [ 2, 4 ]
            }
        ]
    }
    """
end

@testset "_resolve_path" begin
    d = Dict{String,Any}(
        "a" => Dict{String,Any}(
            "b" => Dict{String,Any}("c" => 42),
            "flat" => "hello",
        ),
        "top" => 99,
    )

    @testset "resolves single-key path" begin
        @test SDDPlab._resolve_path(d, "top") == 99
    end

    @testset "resolves two-level path" begin
        @test SDDPlab._resolve_path(d, "a.flat") == "hello"
    end

    @testset "resolves three-level path" begin
        @test SDDPlab._resolve_path(d, "a.b.c") == 42
    end

    @testset "returns nothing for missing top-level key" begin
        @test SDDPlab._resolve_path(d, "z") === nothing
    end

    @testset "returns nothing for missing nested key" begin
        @test SDDPlab._resolve_path(d, "a.x") === nothing
    end

    @testset "returns nothing when intermediate value is not a Dict" begin
        @test SDDPlab._resolve_path(d, "a.flat.sub") === nothing
    end

    @testset "returns nothing for deep missing path" begin
        @test SDDPlab._resolve_path(d, "a.b.c.d") === nothing
    end
end

@testset "_set_path!" begin
    @testset "sets a top-level key" begin
        d = Dict{String,Any}()
        SDDPlab._set_path!(d, "x", 10)
        @test d["x"] == 10
    end

    @testset "sets a nested key creating intermediate dicts" begin
        d = Dict{String,Any}()
        SDDPlab._set_path!(d, "a.b.c", 42)
        @test d["a"]["b"]["c"] == 42
    end

    @testset "overwrites existing leaf value" begin
        d = Dict{String,Any}("a" => Dict{String,Any}("b" => 1))
        SDDPlab._set_path!(d, "a.b", 99)
        @test d["a"]["b"] == 99
    end

    @testset "overwrites existing dict at leaf with scalar" begin
        d = Dict{String,Any}("a" => Dict{String,Any}("b" => Dict{String,Any}("c" => 1)))
        SDDPlab._set_path!(d, "a.b", "flat")
        @test d["a"]["b"] == "flat"
    end

    @testset "handles dict value at leaf" begin
        d = Dict{String,Any}()
        v = Dict{String,Any}("kind" => "CVaR", "params" => Dict{String,Any}("alpha" => 0.2))
        SDDPlab._set_path!(d, "policy.risk_measure", v)
        @test d["policy"]["risk_measure"]["kind"] == "CVaR"
        @test d["policy"]["risk_measure"]["params"]["alpha"] == 0.2
    end

    @testset "replaces non-Dict intermediate with Dict when path requires it" begin
        d = Dict{String,Any}("a" => "was_scalar")
        SDDPlab._set_path!(d, "a.b", 5)
        @test d["a"]["b"] == 5
    end

    @testset "returns the mutated dict" begin
        d = Dict{String,Any}()
        result = SDDPlab._set_path!(d, "x", 1)
        @test result === d
    end
end

@testset "_sanitize_config_name" begin
    @testset "lowercases input" begin
        @test SDDPlab._sanitize_config_name("Alpha") == "alpha"
    end

    @testset "replaces space with underscore" begin
        @test SDDPlab._sanitize_config_name("risk measure") == "risk_measure"
    end

    @testset "replaces dot with underscore" begin
        @test SDDPlab._sanitize_config_name("alpha_0.2") == "alpha_0_2"
    end

    @testset "collapses consecutive underscores" begin
        @test SDDPlab._sanitize_config_name("a__b") == "a_b"
    end

    @testset "strips leading and trailing underscores" begin
        @test SDDPlab._sanitize_config_name("_hello_") == "hello"
    end

    @testset "truncates to 60 characters" begin
        long_str = repeat("a", 80)
        result = SDDPlab._sanitize_config_name(long_str)
        @test length(result) <= 60
    end

    @testset "returns config for empty-after-sanitize input" begin
        @test SDDPlab._sanitize_config_name("...") == "config"
    end

    @testset "handles mixed special chars" begin
        result = SDDPlab._sanitize_config_name("CVaR alpha (0.2)!")
        @test !occursin(r"[^a-z0-9_-]", result)
    end

    @testset "alphanumeric-only input unchanged" begin
        @test SDDPlab._sanitize_config_name("abc123") == "abc123"
    end
end

@testset "_generate_oat_configs" begin
    @testset "2 params (3 and 2 values) produces 5 configs" begin
        params = [
            SensitivityParameter("alpha", "policy.alpha", Any[0.1, 0.2, 0.5]),
            SensitivityParameter("beta",  "policy.beta",  Any[1, 2]),
        ]
        configs = SDDPlab._generate_oat_configs(Dict{String,Any}(), params)
        @test length(configs) == 5
    end

    @testset "each config has a unique name" begin
        params = [
            SensitivityParameter("alpha", "policy.alpha", Any[0.1, 0.2, 0.5]),
            SensitivityParameter("beta",  "policy.beta",  Any[1, 2]),
        ]
        configs = SDDPlab._generate_oat_configs(Dict{String,Any}(), params)
        names = [c[1] for c in configs]
        @test length(unique(names)) == length(names)
    end

    @testset "base_overrides applied to every config" begin
        base = Dict{String,Any}("solver" => Dict{String,Any}("name" => "HiGHS"))
        params = [
            SensitivityParameter("x", "policy.x", Any[1, 2]),
        ]
        configs = SDDPlab._generate_oat_configs(base, params)
        for (_, overrides) in configs
            @test get(overrides, "solver", nothing) isa Dict
            @test overrides["solver"]["name"] == "HiGHS"
        end
    end

    @testset "parameter value is set at the correct path" begin
        params = [
            SensitivityParameter("alpha", "policy.risk.alpha", Any[0.9]),
        ]
        configs = SDDPlab._generate_oat_configs(Dict{String,Any}(), params)
        @test length(configs) == 1
        _, overrides = configs[1]
        @test overrides["policy"]["risk"]["alpha"] == 0.9
    end

    @testset "configs are independent (mutating one does not affect others)" begin
        params = [
            SensitivityParameter("x", "a.b", Any[1, 2]),
        ]
        configs = SDDPlab._generate_oat_configs(Dict{String,Any}(), params)
        _, o1 = configs[1]
        _, o2 = configs[2]
        o1["a"]["b"] = 999
        @test o2["a"]["b"] == 2
    end

    @testset "1 param (1 value) produces 1 config" begin
        params = [SensitivityParameter("x", "p.x", Any[42])]
        configs = SDDPlab._generate_oat_configs(Dict{String,Any}(), params)
        @test length(configs) == 1
    end
end

@testset "_generate_factorial_configs" begin
    @testset "2 params (3 and 2 values) produces 6 configs" begin
        params = [
            SensitivityParameter("alpha", "policy.alpha", Any[0.1, 0.2, 0.5]),
            SensitivityParameter("beta",  "policy.beta",  Any[1, 2]),
        ]
        configs = SDDPlab._generate_factorial_configs(Dict{String,Any}(), params)
        @test length(configs) == 6
    end

    @testset "2 params (2 and 2 values) produces 4 configs" begin
        params = [
            SensitivityParameter("x", "p.x", Any[1, 2]),
            SensitivityParameter("y", "p.y", Any["a", "b"]),
        ]
        configs = SDDPlab._generate_factorial_configs(Dict{String,Any}(), params)
        @test length(configs) == 4
    end

    @testset "each config has a unique name" begin
        params = [
            SensitivityParameter("alpha", "policy.alpha", Any[0.1, 0.2, 0.5]),
            SensitivityParameter("beta",  "policy.beta",  Any[1, 2]),
        ]
        configs = SDDPlab._generate_factorial_configs(Dict{String,Any}(), params)
        names = [c[1] for c in configs]
        @test length(unique(names)) == length(names)
    end

    @testset "both parameters are set in each generated config" begin
        params = [
            SensitivityParameter("x", "a.x", Any[10, 20]),
            SensitivityParameter("y", "a.y", Any[1, 2]),
        ]
        configs = SDDPlab._generate_factorial_configs(Dict{String,Any}(), params)
        for (_, overrides) in configs
            @test haskey(overrides["a"], "x")
            @test haskey(overrides["a"], "y")
        end
    end

    @testset "all combinations are distinct" begin
        params = [
            SensitivityParameter("x", "p.x", Any[1, 2]),
            SensitivityParameter("y", "p.y", Any["a", "b"]),
        ]
        configs = SDDPlab._generate_factorial_configs(Dict{String,Any}(), params)
        combos = [(o["p"]["x"], o["p"]["y"]) for (_, o) in configs]
        @test length(unique(combos)) == 4
    end

    @testset "base_overrides present in all factorial configs" begin
        base = Dict{String,Any}("solver" => "HiGHS")
        params = [
            SensitivityParameter("x", "p.x", Any[1, 2]),
            SensitivityParameter("y", "p.y", Any[3, 4]),
        ]
        configs = SDDPlab._generate_factorial_configs(base, params)
        for (_, overrides) in configs
            @test get(overrides, "solver", nothing) == "HiGHS"
        end
    end
end

@testset "read_sensitivity_config" begin
    example = _example_dir()

    mktempdir() do tmpdir
        @testset "valid OAT config parses successfully" begin
            content = _minimal_oat_jsonc(example, joinpath(tmpdir, "out"))
            path = _write_sensitivity_jsonc(tmpdir, content)
            cfg = read_sensitivity_config(path)
            @test cfg isa SensitivityConfig
            @test cfg.base_study == example
            @test cfg.mode == "oat"
            @test length(cfg.parameters) == 1
            @test cfg.parameters[1].label == "risk_measure"
            @test length(cfg.parameters[1].values) == 2
        end

        @testset "mode defaults to oat when omitted" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": [
                    { "path": "policy.x", "label": "x", "values": [1, 2] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            cfg = read_sensitivity_config(path)
            @test cfg.mode == "oat"
        end

        @testset "base_overrides defaults to empty dict when omitted" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": [
                    { "path": "policy.x", "label": "x", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            cfg = read_sensitivity_config(path)
            @test isempty(cfg.base_overrides)
        end

        @testset "overwrite defaults to false" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": [
                    { "path": "policy.x", "label": "x", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            cfg = read_sensitivity_config(path)
            @test cfg.overwrite == false
        end

        @testset "missing base_study throws" begin
            content = """
            {
                "parameters": [
                    { "path": "p", "label": "l", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "missing parameters throws" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped"
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "empty parameters array throws" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": []
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "invalid mode throws" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "mode": "invalid_mode",
                "parameters": [
                    { "path": "p", "label": "l", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "parameter missing path throws" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": [
                    { "label": "x", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "parameter with empty values throws" begin
            example_escaped = replace(example, "\\" => "/")
            content = """
            {
                "base_study": "$example_escaped",
                "parameters": [
                    { "path": "p", "label": "l", "values": [] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "base_study not a directory throws" begin
            content = """
            {
                "base_study": "/nonexistent/path",
                "parameters": [
                    { "path": "p", "label": "l", "values": [1] }
                ]
            }
            """
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws CompositeException read_sensitivity_config(path)
        end

        @testset "relative base_study resolved against sensitivity dir" begin
            parent_dir = dirname(example)
            example_basename = basename(example)
            content = """
            {
                "base_study": "$(example_basename)",
                "parameters": [
                    { "path": "p", "label": "l", "values": [1] }
                ]
            }
            """
            exp_path = joinpath(parent_dir, "sensitivity_rel_test.jsonc")
            try
                open(exp_path, "w") do io
                    write(io, content)
                end
                cfg = read_sensitivity_config(exp_path)
                @test cfg.base_study == abspath(example)
            finally
                isfile(exp_path) && rm(exp_path)
            end
        end
    end
end

@testset "run_sensitivity OAT integration" begin
    example = _example_dir()

    @testset "1 parameter with 2 values produces 2 output dirs and summary CSV" begin
        mktempdir() do tmpdir
            out_dir = joinpath(tmpdir, "results")
            content = _minimal_oat_jsonc(example, out_dir; max_iterations = 3, num_simulations = 2)
            path = _write_sensitivity_jsonc(tmpdir, content)

            result = run_sensitivity(path)

            @test result isa SensitivityResult
            @test result.mode == "oat"
            @test length(result.parameters) == 1
            @test length(result.results) == 2

            for r in result.results
                @test r.success == true
                @test r.error_message === nothing
                @test isdir(r.output_path)
            end

            names = [r.config_name for r in result.results]
            @test length(unique(names)) == 2

            @test isfile(result.summary_path)
            csv_data = CSV.File(result.summary_path)
            @test length(csv_data) == 2
            col_names = propertynames(csv_data)
            @test :config_name       in col_names
            @test :parameter_label   in col_names
            @test :parameter_value   in col_names
            @test :success           in col_names
            @test :train_time_s      in col_names
            @test :simulate_time_s   in col_names
            @test :error             in col_names

            for row in csv_data
                @test row.parameter_label == "risk_measure"
            end

            @test all(row.success for row in csv_data)
        end
    end

    @testset "base_overrides are applied: max_iterations respected" begin
        mktempdir() do tmpdir
            out_dir = joinpath(tmpdir, "results")
            content = _minimal_oat_jsonc(example, out_dir; max_iterations = 3, num_simulations = 2)
            path = _write_sensitivity_jsonc(tmpdir, content)

            t_start = time()
            result = run_sensitivity(path)
            t_elapsed = time() - t_start

            @test all(r.success for r in result.results)
            @test t_elapsed < 60.0
        end
    end

    @testset "overwrite false on non-empty output dir throws" begin
        mktempdir() do tmpdir
            out_dir = joinpath(tmpdir, "results")
            mkpath(out_dir)
            open(joinpath(out_dir, "existing.txt"), "w") do io; write(io, "x"); end

            content = _minimal_oat_jsonc(example, out_dir; overwrite = false)
            path = _write_sensitivity_jsonc(tmpdir, content)
            @test_throws Exception run_sensitivity(path)
        end
    end
end

@testset "run_sensitivity factorial integration" begin
    example = _example_dir()

    @testset "2 parameters with 2 values each produces 4 output dirs" begin
        mktempdir() do tmpdir
            out_dir = joinpath(tmpdir, "results")
            content = _minimal_factorial_jsonc(example, out_dir; max_iterations = 3)
            path = _write_sensitivity_jsonc(tmpdir, content)

            result = run_sensitivity(path)

            @test result isa SensitivityResult
            @test result.mode == "factorial"
            @test length(result.parameters) == 2
            @test length(result.results) == 4

            for r in result.results
                @test r.success == true
                @test isdir(r.output_path)
            end

            names = [r.config_name for r in result.results]
            @test length(unique(names)) == 4

            @test isfile(result.summary_path)
            csv_data = CSV.File(result.summary_path)
            @test length(csv_data) == 4
            @test all(row.success for row in csv_data)

            for row in csv_data
                @test occursin("risk_measure", row.parameter_label)
                @test occursin("num_simulations", row.parameter_label)
            end
        end
    end
end
