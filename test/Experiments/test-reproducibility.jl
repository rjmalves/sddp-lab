using Test
using SDDPlab
using JSON

_example_dir() = abspath(joinpath(@__DIR__, "..", "..", "example", "1dtoy"))

function _write_repro_experiment(dir::String, num_simulations::Int = 2)
    example = _example_dir()
    example_escaped = replace(example, "\\" => "/")
    content = """
    {
        "base_study": "$example_escaped",
        "output_dir": "$(replace(joinpath(dir, "results"), "\\" => "/"))",
        "overwrite": true,
        "configurations": {
            "repro_cfg": {
                "policy": {
                    "convergence": {
                        "min_iterations": 1,
                        "max_iterations": 3,
                        "stopping_criteria": {
                            "kind": "IterationLimit",
                            "params": { "num_iterations": 3 }
                        }
                    }
                },
                "simulation": {
                    "num_simulated_series": $num_simulations,
                    "parallel_scheme": {
                        "kind": "Serial",
                        "params": {}
                    }
                }
            }
        }
    }
    """
    path = joinpath(dir, "experiment.jsonc")
    open(path, "w") do io
        write(io, content)
    end
    return path
end

@testset "hash_config" begin
    @testset "identical dicts produce identical hashes" begin
        d1 = Dict{String,Any}("alpha" => 0.5, "beta" => 1.0, "kind" => "CVaR")
        d2 = Dict{String,Any}("alpha" => 0.5, "beta" => 1.0, "kind" => "CVaR")
        @test hash_config(d1) == hash_config(d2)
    end

    @testset "dicts differing in one leaf value produce different hashes" begin
        d1 = Dict{String,Any}("alpha" => 0.5, "lambda" => 0.9)
        d2 = Dict{String,Any}("alpha" => 0.5, "lambda" => 0.1)
        @test hash_config(d1) != hash_config(d2)
    end

    @testset "key insertion order does not affect hash" begin
        d1 = Dict{String,Any}()
        d1["z_key"] = 26
        d1["a_key"] = 1
        d1["m_key"] = 13

        d2 = Dict{String,Any}()
        d2["a_key"] = 1
        d2["m_key"] = 13
        d2["z_key"] = 26

        @test hash_config(d1) == hash_config(d2)
    end

    @testset "hash is a 64-character hex string" begin
        d = Dict{String,Any}("x" => 1)
        h = hash_config(d)
        @test length(h) == 64
        @test all(c -> c in "0123456789abcdef", h)
    end

    @testset "nested dicts are sorted recursively" begin
        d1 = Dict{String,Any}(
            "policy" => Dict{String,Any}("z_param" => 1.0, "a_param" => 2.0),
            "solver" => "HiGHS",
        )
        d2 = Dict{String,Any}(
            "solver" => "HiGHS",
            "policy" => Dict{String,Any}("a_param" => 2.0, "z_param" => 1.0),
        )
        @test hash_config(d1) == hash_config(d2)
    end

    @testset "empty dict has a stable hash" begin
        d1 = Dict{String,Any}()
        d2 = Dict{String,Any}()
        @test hash_config(d1) == hash_config(d2)
    end

    @testset "array values are preserved in order" begin
        # Arrays are NOT sorted — only Dict keys are; different order means different hash.
        d1 = Dict{String,Any}("items" => [1, 2, 3])
        d2 = Dict{String,Any}("items" => [3, 2, 1])
        @test hash_config(d1) != hash_config(d2)
    end
end

@testset "capture_environment" begin
    @testset "returns a valid EnvironmentSnapshot" begin
        env = capture_environment()
        @test env isa EnvironmentSnapshot
    end

    @testset "julia_version matches VERSION" begin
        env = capture_environment()
        @test env.julia_version == string(VERSION)
    end

    @testset "num_threads matches Threads.nthreads()" begin
        env = capture_environment()
        @test env.num_threads == Threads.nthreads()
    end

    @testset "os_machine is non-empty" begin
        env = capture_environment()
        @test !isempty(env.os_machine)
    end

    @testset "timestamp is non-empty and looks like ISO 8601" begin
        env = capture_environment()
        @test !isempty(env.timestamp)
        @test occursin('T', env.timestamp)  # ISO 8601 uses 'T' as date/time separator
    end

    @testset "package_versions is a Dict{String,String}" begin
        env = capture_environment()
        @test env.package_versions isa Dict{String,String}
    end
end

@testset "verify_reproducibility" begin
    @testset "matching metadata returns true" begin
        mktempdir() do tmpdir
            config = Dict{String,Any}("alpha" => 0.5, "kind" => "CVaR")
            env = capture_environment()

            dir_a = joinpath(tmpdir, "run_a")
            dir_b = joinpath(tmpdir, "run_b")
            mkpath(dir_a)
            mkpath(dir_b)

            write_run_metadata(tmpdir, "run_a", config, env)
            write_run_metadata(tmpdir, "run_b", config, env)

            @test verify_reproducibility(dir_a, dir_b) == true
        end
    end

    @testset "differing configs returns false" begin
        mktempdir() do tmpdir
            config_a = Dict{String,Any}("alpha" => 0.5, "kind" => "CVaR")
            config_b = Dict{String,Any}("alpha" => 0.1, "kind" => "CVaR")
            env = capture_environment()

            dir_a = joinpath(tmpdir, "cfg_a")
            dir_b = joinpath(tmpdir, "cfg_b")
            mkpath(dir_a)
            mkpath(dir_b)

            write_run_metadata(tmpdir, "cfg_a", config_a, env)
            write_run_metadata(tmpdir, "cfg_b", config_b, env)

            @test verify_reproducibility(dir_a, dir_b) == false
        end
    end

    @testset "missing metadata.json returns false with warning" begin
        mktempdir() do tmpdir
            dir_a = joinpath(tmpdir, "exists")
            dir_b = joinpath(tmpdir, "missing")
            mkpath(dir_a)
            mkpath(dir_b)

            config = Dict{String,Any}("alpha" => 0.5)
            env = capture_environment()
            write_run_metadata(tmpdir, "exists", config, env)
            # dir_b has no metadata.json

            @test_logs (:warn,) match_mode = :any verify_reproducibility(dir_a, dir_b) ==
                false
        end
    end

    @testset "both missing metadata.json returns false" begin
        mktempdir() do tmpdir
            dir_a = joinpath(tmpdir, "no_meta_a")
            dir_b = joinpath(tmpdir, "no_meta_b")
            mkpath(dir_a)
            mkpath(dir_b)

            result = verify_reproducibility(dir_a, dir_b)
            @test result == false
        end
    end
end

@testset "write_run_metadata" begin
    @testset "produces valid JSON with all required sections" begin
        mktempdir() do tmpdir
            config = Dict{String,Any}(
                "policy" => Dict{String,Any}("kind" => "CVaR", "alpha" => 0.2),
                "solver" => "HiGHS",
            )
            env = capture_environment()
            seeds = Dict{String,Any}("saa_seed" => 42)

            cfg_dir = joinpath(tmpdir, "my_config")
            mkpath(cfg_dir)
            write_run_metadata(tmpdir, "my_config", config, env; seeds = seeds)

            meta_path = joinpath(cfg_dir, "metadata.json")
            @test isfile(meta_path)

            parsed = JSON.parsefile(meta_path)
            @test haskey(parsed, "config_hash")
            @test haskey(parsed, "config")
            @test haskey(parsed, "environment")
            @test haskey(parsed, "seeds")
        end
    end

    @testset "config_hash matches hash_config of the same dict" begin
        mktempdir() do tmpdir
            config = Dict{String,Any}("alpha" => 0.3, "lambda" => 0.7)
            env = capture_environment()

            cfg_dir = joinpath(tmpdir, "cfg")
            mkpath(cfg_dir)
            write_run_metadata(tmpdir, "cfg", config, env)

            parsed = JSON.parsefile(joinpath(cfg_dir, "metadata.json"))
            expected_hash = hash_config(config)
            @test parsed["config_hash"] == expected_hash
        end
    end

    @testset "environment section contains julia_version and num_threads" begin
        mktempdir() do tmpdir
            config = Dict{String,Any}("x" => 1)
            env = capture_environment()

            cfg_dir = joinpath(tmpdir, "env_test")
            mkpath(cfg_dir)
            write_run_metadata(tmpdir, "env_test", config, env)

            parsed = JSON.parsefile(joinpath(cfg_dir, "metadata.json"))
            env_section = parsed["environment"]
            @test env_section["julia_version"] == string(VERSION)
            @test env_section["num_threads"] == Threads.nthreads()
        end
    end

    @testset "seeds section is included" begin
        mktempdir() do tmpdir
            config = Dict{String,Any}("y" => 2)
            env = capture_environment()
            seeds = Dict{String,Any}("saa_seed" => 999, "validation_seed" => nothing)

            cfg_dir = joinpath(tmpdir, "seed_test")
            mkpath(cfg_dir)
            write_run_metadata(tmpdir, "seed_test", config, env; seeds = seeds)

            parsed = JSON.parsefile(joinpath(cfg_dir, "metadata.json"))
            @test parsed["seeds"]["saa_seed"] == 999
        end
    end

    @testset "failure does not throw (non-fatal)" begin
        config = Dict{String,Any}("x" => 1)
        env = capture_environment()
        @test_logs (:warn,) match_mode = :any begin
            write_run_metadata("/nonexistent/path", "cfg_name", config, env)
        end
    end
end

@testset "run_experiment produces metadata.json" begin
    @testset "metadata.json exists after successful run" begin
        mktempdir() do tmpdir
            exp_path = _write_repro_experiment(tmpdir)
            results = run_experiment(exp_path)

            @test length(results) >= 1
            successful = filter(r -> r.success, results)
            @test !isempty(successful)

            for r in successful
                meta_path = joinpath(r.output_path, "metadata.json")
                @test isfile(meta_path)
            end
        end
    end

    @testset "metadata.json has all required top-level keys" begin
        mktempdir() do tmpdir
            exp_path = _write_repro_experiment(tmpdir)
            results = run_experiment(exp_path)

            successful = filter(r -> r.success, results)
            @test !isempty(successful)

            r = successful[1]
            meta_path = joinpath(r.output_path, "metadata.json")
            parsed = JSON.parsefile(meta_path)

            @test haskey(parsed, "config_hash")
            @test haskey(parsed, "config")
            @test haskey(parsed, "environment")
            @test haskey(parsed, "seeds")
        end
    end

    @testset "config_hash is a non-empty hex string" begin
        mktempdir() do tmpdir
            exp_path = _write_repro_experiment(tmpdir)
            results = run_experiment(exp_path)

            successful = filter(r -> r.success, results)
            @test !isempty(successful)

            r = successful[1]
            parsed = JSON.parsefile(joinpath(r.output_path, "metadata.json"))
            ch = parsed["config_hash"]
            @test ch isa String
            @test length(ch) == 64
            @test all(c -> c in "0123456789abcdef", ch)
        end
    end

    @testset "environment section has julia_version and num_threads" begin
        mktempdir() do tmpdir
            exp_path = _write_repro_experiment(tmpdir)
            results = run_experiment(exp_path)

            successful = filter(r -> r.success, results)
            @test !isempty(successful)

            r = successful[1]
            parsed = JSON.parsefile(joinpath(r.output_path, "metadata.json"))
            env_section = parsed["environment"]
            @test env_section["julia_version"] == string(VERSION)
            @test env_section["num_threads"] isa Int
        end
    end

    @testset "seeds section contains saa_seed" begin
        mktempdir() do tmpdir
            exp_path = _write_repro_experiment(tmpdir)
            results = run_experiment(exp_path)

            successful = filter(r -> r.success, results)
            @test !isempty(successful)

            r = successful[1]
            parsed = JSON.parsefile(joinpath(r.output_path, "metadata.json"))
            seeds_section = parsed["seeds"]
            @test haskey(seeds_section, "saa_seed")
        end
    end

    @testset "config_hash is deterministic across two runs of same config" begin
        mktempdir() do tmpdir1
            mktempdir() do tmpdir2
                exp_path1 = _write_repro_experiment(tmpdir1)
                exp_path2 = _write_repro_experiment(tmpdir2)

                results1 = run_experiment(exp_path1)
                results2 = run_experiment(exp_path2)

                succ1 = filter(r -> r.success, results1)
                succ2 = filter(r -> r.success, results2)
                @test !isempty(succ1) && !isempty(succ2)

                parsed1 = JSON.parsefile(joinpath(succ1[1].output_path, "metadata.json"))
                parsed2 = JSON.parsefile(joinpath(succ2[1].output_path, "metadata.json"))

                @test parsed1["config_hash"] == parsed2["config_hash"]
            end
        end
    end

    @testset "verify_reproducibility returns true for two identical-config runs" begin
        mktempdir() do tmpdir1
            mktempdir() do tmpdir2
                exp_path1 = _write_repro_experiment(tmpdir1)
                exp_path2 = _write_repro_experiment(tmpdir2)

                results1 = run_experiment(exp_path1)
                results2 = run_experiment(exp_path2)

                succ1 = filter(r -> r.success, results1)
                succ2 = filter(r -> r.success, results2)
                @test !isempty(succ1) && !isempty(succ2)

                @test verify_reproducibility(succ1[1].output_path, succ2[1].output_path) ==
                    true
            end
        end
    end
end
