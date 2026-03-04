using Test

@testset "test-precompile" begin
    @testset "precompile-produces-no-stdout" begin
        # Force re-precompilation by clearing the SDDPlab cache.
        # Precompilation only runs on the first import after cache invalidation,
        # so this test must use a subprocess.
        cache_dir = joinpath(
            first(DEPOT_PATH), "compiled", "v$(VERSION.major).$(VERSION.minor)", "SDDPlab"
        )
        if isdir(cache_dir)
            for f in readdir(cache_dir; join = true)
                rm(f; force = true)
            end
        end

        project_dir = joinpath(@__DIR__, "..")
        cmd = `$(Base.julia_cmd()) --project=$(project_dir) -e "using SDDPlab"`

        stdout_buf = IOBuffer()
        stderr_buf = IOBuffer()
        run(pipeline(cmd; stdout = stdout_buf, stderr = stderr_buf); wait = true)

        stdout_output = String(take!(stdout_buf))
        stderr_output = String(take!(stderr_buf))

        @test isempty(stdout_output)

        forbidden_stdout_patterns = [
            "HiGHS",
            "Running HiGHS",
            "Iteration",
            "iteration",
            "Presolve",
            "Solving",
            "Lower bound",
            "Upper bound",
            "MIP",
            "Optimal",
        ]
        for pattern in forbidden_stdout_patterns
            @test !occursin(pattern, stdout_output)
        end

        # Solver/JuMP output sometimes goes to stderr rather than stdout
        forbidden_stderr_patterns = [
            "Running HiGHS",
            "HiGHS version",
            "Model   name",
            "SDDP.jl",
            "Lower bound",
            "Upper bound",
        ]
        for pattern in forbidden_stderr_patterns
            @test !occursin(pattern, stderr_output)
        end
    end
end
