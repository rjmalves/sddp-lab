# Epic 04: Parallelization and Performance

## Goal

Enable full parallelization support (threading and distributed computing) via SDDP.jl's parallel schemes, ensure thread-safe scenario generation, and optimize hot paths for performance.

## Primary Agent

`hpc-julia-developer` -- This epic is HPC-focused: threading with `Threads.@spawn`, MPI.jl distributed computing, profiling with `Profile.jl` and `BenchmarkTools.jl`, thread-safe RNG management, and zero-allocation optimization. The `sddp-specialist` reviews thread-safety of SDDP-specific data structures and verifies SAA reproducibility.

## Scope

- Full integration with SDDP.jl's `Threaded()` parallel scheme
- Distributed computing support via `Asynchronous()` with worker management
- Thread-safe SAA generation and RNG management
- Performance profiling and optimization of model building
- Solver warm-starting support

## Tickets

| ID         | Title                                            | Estimate | Agent               |
| ---------- | ------------------------------------------------ | -------- | ------------------- |
| ticket-017 | Enable threaded parallel training and simulation | 3 pts    | hpc-julia-developer |
| ticket-018 | Implement thread-safe SAA generation             | 3 pts    | hpc-julia-developer |
| ticket-019 | Profile and optimize model building hot paths    | 4 pts    | hpc-julia-developer |
| ticket-020 | Add distributed computing support                | 3 pts    | hpc-julia-developer |

## Dependencies

- Epic 03 must be complete
