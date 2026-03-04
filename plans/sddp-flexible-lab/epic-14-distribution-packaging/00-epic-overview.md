# Epic 14: Distribution & Packaging

## Goal

Create a distributable self-contained application using PackageCompiler's `create_app`, enabling users without Julia installed to run SDDPlab. This includes adding a `julia_main()::Cint` entry point, creating the build script, and producing architecture-specific tarballs.

## Scope

- Add `julia_main()::Cint` entry point to SDDPlab module with CLI argument parsing
- Create `build/build_app.jl` script using PackageCompiler's `create_app`
- Produce tarballs: `sddp-lab-v{version}-{os}-{arch}.tar.gz`
- Validate the built app can run the 1dtoy example case end-to-end

## Non-Goals

- MPI support in the compiled app (future work)
- Pkg Apps / `@main` integration (experimental, not stable enough)
- Cross-compilation (each platform builds natively)
- Windows support (Linux x86_64 only for initial release)

## Tickets

| Ticket     | Title                                                | Agent               | Points |
| ---------- | ---------------------------------------------------- | ------------------- | ------ |
| ticket-054 | Add julia_main entry point with CLI argument parsing | hpc-julia-developer | 3      |
| ticket-055 | Create build_app.jl script and tarball packaging     | hpc-julia-developer | 3      |

## Dependencies

- Depends on: Epic 13 (precompile workload feeds into create_app)
- Blocks: Epic 15 (CI release pipeline automates the build)
