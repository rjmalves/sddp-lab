# Usage: julia --project=build build/build_app.jl [output_dir]
# JULIA_CPU_TARGET: CPU target for the sysimage (default: "generic" for portability)

using PackageCompiler

project_dir = dirname(@__DIR__)
output_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "SDDPLabApp")

@info "Building SDDPlab app" project = project_dir output = output_dir

create_app(
    project_dir,
    output_dir;
    precompile_execution_file = joinpath(@__DIR__, "precompile_execution.jl"),
    incremental = false,
    include_lazy_artifacts = true,
    cpu_target = get(ENV, "JULIA_CPU_TARGET", "generic"),
    force = true,
)

@info "Build complete" output = output_dir
