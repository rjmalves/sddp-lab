# ticket-055 Create build_app.jl Script and Tarball Packaging

## Context

### Background

With the `julia_main()::Cint` entry point in place (ticket-054) and the precompile workload caching native code (Epic 13), this ticket creates the `build/build_app.jl` script that uses PackageCompiler's `create_app` to produce a self-contained distributable application. The output is a directory containing the SDDPlab executable, the Julia runtime, and all dependency artifacts (including HiGHS). A companion script packages this directory into a versioned tarball.

### Relation to Epic

This is the second and final ticket in Epic 14. It produces the actual distributable artifact that Epic 15 (CI release pipeline) will automate.

### Current State

- `julia_main()::Cint` exists in `src/main.jl` (from ticket-054) and is exported from `SDDPlab`
- The precompile workload in `src/precompile_workload.jl` exercises the hot SDDP path (from Epic 13)
- `Project.toml` has `version = "3.0.0"` and lists all dependencies including HiGHS and PrecompileTools
- There is no `build/` directory and no PackageCompiler dependency
- The `example/1dtoy/` directory contains a minimal test case

## Specification

### Requirements

1. Create `/home/rogerio/git/sddp-lab/build/build_app.jl` that:
   - Uses `PackageCompiler.create_app` to produce a self-contained app directory
   - Points to the project root as the source package
   - Uses `src/precompile_workload.jl` as the `precompile_execution_file`
   - Sets `cpu_target` from `ENV["JULIA_CPU_TARGET"]` or defaults to `"generic"`
   - Sets `include_lazy_artifacts = true` (for HiGHS binary)
   - Sets `incremental = false` for a full sysimage bake
   - Outputs to `build/SDDPLabApp/` by default, configurable via CLI arg
2. Create `/home/rogerio/git/sddp-lab/build/package_tarball.sh` that:
   - Takes the app directory as input
   - Reads the version from `Project.toml`
   - Detects OS and architecture
   - Produces `sddp-lab-v{version}-{os}-{arch}.tar.gz`
3. Add a `build/Project.toml` that declares PackageCompiler as a dependency (the build environment is separate from the main project)
4. Add `build/` and `*.tar.gz` entries to `.gitignore` (the app directory and tarballs should not be committed)
5. The built app must be able to run: `build/SDDPLabApp/bin/SDDPlab example/1dtoy/`

### Inputs/Props

- Project root at `/home/rogerio/git/sddp-lab/`
- `src/precompile_workload.jl` (from Epic 13)
- `julia_main()::Cint` (from ticket-054)

### Outputs/Behavior

- `build/SDDPLabApp/` directory containing: `bin/SDDPlab` executable, `lib/` with Julia runtime, `artifacts/` with HiGHS binary
- `sddp-lab-v3.0.0-linux-x86_64.tar.gz` (or equivalent for the build platform)
- The executable runs the SDDPlab pipeline without requiring a Julia installation

### Error Handling

- `build_app.jl` should print clear error messages if PackageCompiler is not installed
- `package_tarball.sh` should fail with a clear message if the app directory does not exist

## Acceptance Criteria

- [ ] Given `/home/rogerio/git/sddp-lab/build/build_app.jl`, when run with `julia --project=build build/build_app.jl`, then a `build/SDDPLabApp/` directory is produced containing `bin/SDDPlab`, `lib/julia/`, and HiGHS artifacts
- [ ] Given the built app, when `build/SDDPLabApp/bin/SDDPlab example/1dtoy/` is run, then the 1dtoy study executes successfully (exit code 0) and output files are written to `example/1dtoy/data/`
- [ ] Given the built app, when `build/SDDPLabApp/bin/SDDPlab --version` is run, then "SDDPlab v3.0.0" is printed
- [ ] Given `/home/rogerio/git/sddp-lab/build/package_tarball.sh`, when run after build_app.jl, then a file `sddp-lab-v3.0.0-linux-x86_64.tar.gz` is produced in `build/`
- [ ] Given `.gitignore`, when inspected, then `build/SDDPLabApp/` and `*.tar.gz` patterns are present

## Implementation Guide

### Suggested Approach

1. Create `/home/rogerio/git/sddp-lab/build/Project.toml`:

```toml
[deps]
PackageCompiler = "9b87118b-4619-50d2-8e1e-99f35a4d4d9d"

[compat]
PackageCompiler = ">= 2.1"
```

2. Create `/home/rogerio/git/sddp-lab/build/build_app.jl`:

```julia
using PackageCompiler

project_dir = dirname(@__DIR__)
output_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "SDDPLabApp")

@info "Building SDDPlab app" project=project_dir output=output_dir

create_app(
    project_dir,
    output_dir;
    precompile_execution_file = joinpath(project_dir, "src", "precompile_workload.jl"),
    incremental = false,
    include_lazy_artifacts = true,
    cpu_target = get(ENV, "JULIA_CPU_TARGET", "generic"),
    force = true,
)

@info "Build complete" output=output_dir
```

3. Create `/home/rogerio/git/sddp-lab/build/package_tarball.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="${1:-$SCRIPT_DIR/SDDPLabApp}"

if [ ! -d "$APP_DIR" ]; then
    echo "Error: App directory not found: $APP_DIR"
    echo "Run 'julia --project=build build/build_app.jl' first."
    exit 1
fi

VERSION=$(grep '^version' "$PROJECT_DIR/Project.toml" | sed 's/.*"\(.*\)"/\1/')
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

TARBALL="$SCRIPT_DIR/sddp-lab-v${VERSION}-${OS}-${ARCH}.tar.gz"

tar -czf "$TARBALL" -C "$(dirname "$APP_DIR")" "$(basename "$APP_DIR")"

echo "Created: $TARBALL"
echo "Size: $(du -h "$TARBALL" | cut -f1)"
```

4. Update `.gitignore` at `/home/rogerio/git/sddp-lab/.gitignore` (create if needed):

```
build/SDDPLabApp/
*.tar.gz
```

5. Note on the `precompile_execution_file` parameter: PackageCompiler runs this file in a fresh Julia session with the sysimage being built. The file must be runnable standalone. Since `src/precompile_workload.jl` is designed to be included inside the `SDDPlab` module's `@compile_workload` block, we need to verify it works when executed by PackageCompiler. If not, create a thin wrapper `build/precompile_execution.jl`:

```julia
using SDDPlab
# The @compile_workload block runs during precompilation, which create_app triggers.
# This file just needs to 'use' the package to trigger precompilation.
# Optionally, run a tiny pipeline to compile runtime paths too:
# (The @compile_workload already covers this, so this may be a no-op)
```

[ASSUMPTION] PackageCompiler's `precompile_execution_file` is run AFTER the sysimage is built, to trigger additional compilation. The `@compile_workload` in SDDPlab.jl already handles precompilation. The `precompile_execution_file` may be used to exercise runtime paths not covered by `@compile_workload`. If PackageCompiler's behavior differs, the `precompile_execution_file` may need to be a standalone script that imports SDDPlab and runs the 1dtoy example. This needs verification during implementation.

### Key Files to Create

- `/home/rogerio/git/sddp-lab/build/Project.toml`
- `/home/rogerio/git/sddp-lab/build/build_app.jl`
- `/home/rogerio/git/sddp-lab/build/package_tarball.sh`

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/.gitignore` (add build artifacts)

### Patterns to Follow

- Follow PackageCompiler.jl documentation's `create_app` example structure
- Use `@__DIR__` for path resolution relative to the build script (standard Julia pattern)
- The tarball naming convention follows the pattern used by Julia releases: `julia-{version}-{os}-{arch}.tar.gz`

### Pitfalls to Avoid

- Do NOT add PackageCompiler to the main `Project.toml` -- it is only needed in the build environment (`build/Project.toml`)
- Do NOT forget `include_lazy_artifacts = true` -- without it, HiGHS's compiled C++ library will not be bundled
- Do NOT use `incremental = true` -- this produces a smaller but less self-contained bundle that may have runtime issues
- Do NOT hardcode `cpu_target` to a specific microarchitecture -- use `"generic"` for maximum portability, allow override via env var
- The `force = true` parameter overwrites any existing app directory -- needed for repeated builds
- The build will take 10-30 minutes and require significant disk space (2-4 GB during build, 400-600 MB final)

## Testing Requirements

### Unit Tests

- Not applicable (build script is tested via integration)

### Integration Tests

- Run `build_app.jl` and verify the output directory structure
- Run the built executable on the 1dtoy example and verify exit code 0 and output files

### E2E Tests

- Full end-to-end: build app -> package tarball -> extract tarball in temp dir -> run on 1dtoy -> verify output

## Dependencies

- **Blocked By**: ticket-054-add-julia-main-entry-point.md
- **Blocks**: ticket-056-add-github-actions-release-workflow.md (Epic 15)

## Effort Estimate

**Points**: 3
**Confidence**: Medium (PackageCompiler build times and artifact inclusion behavior may require iteration)
