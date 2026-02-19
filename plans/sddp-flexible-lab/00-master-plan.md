# Master Plan: Transform SDDPlab into a Fully Flexible SDDP Experimentation Laboratory

## Executive Summary

SDDPlab.jl is a Julia package for experimenting with Stochastic Dual Dynamic Programming (SDDP) algorithm variations in the hydrothermal dispatch problem. The project has a partially-completed refactoring on the `abstract-engine` branch that introduces an Engine abstraction layer separating algorithm implementation from system modeling. This plan completes that refactoring and systematically extends the package to expose the full breadth of SDDP.jl capabilities -- risk measures, stopping rules, sampling schemes, duality handlers, forward passes, and cut types -- while adding units tracking, LP conditioning, parallelization, new system elements, subproblem structure enhancements, advanced stochastic modeling, experiment management, and observability tooling.

## Agent Strategy

This plan leverages two specialist agents for implementation:

| Agent                 | Expertise Domain                                                                                      | Typical Tickets                                                       |
| --------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `hpc-julia-developer` | Julia HPC, JuMP internals, type stability, threading, MPI.jl, SIMD, zero-allocation hot paths, FFI    | Engine abstraction, model building, parallelization, performance, I/O |
| `sddp-specialist`     | SDDP algorithm theory, risk measures, duality, cuts, stopping rules, stochastic modeling, convergence | Algorithm flexibility, stochastic modeling, convergence diagnostics   |

### Agent Assignment Principles

1. **Algorithm design tickets** (risk measures, duality handlers, forward passes, cut types, stopping rules) go to `sddp-specialist` as primary -- they require deep understanding of the mathematical formulations and SDDP.jl's internal API for these concepts.
2. **Infrastructure and engine tickets** (merging branches, graph validation, load refactoring, test coverage, wiring pipelines, validation infrastructure) go to `hpc-julia-developer` as primary -- they require Julia expertise in type systems, validation patterns, and JuMP model construction.
3. **System modeling tickets** (non-controllable generation, energy contracts, pumping stations) require both agents: `sddp-specialist` understands the LP formulations and how they interact with cuts, while `hpc-julia-developer` ensures type-stable, performant implementations.
4. **Parallelization tickets** go to `hpc-julia-developer` as primary with `sddp-specialist` reviewing thread-safety of SDDP-specific data structures.
5. **Stochastic modeling tickets** go to `sddp-specialist` as primary (mathematical modeling) with `hpc-julia-developer` reviewing performance-critical sampling code.
6. **Independent tickets within an epic can be parallelized** across agents when they have no dependency relationship. In Epic 02, tickets 010-015 are all independent -- the sddp-specialist can work on multiple simultaneously while the hpc-julia-developer handles infrastructure tickets.

## Goals

1. **Complete the Engine abstraction** -- merge `abstract-engine` into `main`, fix all TODOs (graph validation, load representation), ensure comprehensive test coverage
2. **Simplify the validation pipeline** -- replace 1900+ lines of boilerplate validator code with a declarative, table-driven schema system that eliminates per-entity repetition while preserving the CompositeException error accumulation pattern
3. **Expose all SDDP.jl algorithm knobs** -- every risk measure, stopping rule, sampling scheme, duality handler, forward pass, and cut type available in SDDP.jl should be configurable via JSONC
4. **Add a variable units system** -- explicit unit tracking in input data with automatic conversion and validation
5. **Implement LP conditioning** -- coefficient scaling, numerical stability diagnostics, solver-specific configuration
6. **Enable parallelization** -- threading and distributed computing via SDDP.jl's parallel schemes
7. **Add new system elements** -- non-controllable generation (renewables), energy contracts (import/export), pumping stations
8. **Enhance subproblem structure** -- stage time duration with MW-to-MWh conversion, inner load blocks (parallel and chronological), inflow non-negativity methods
9. **Advance stochastic modeling** -- multivariate processes, Markov chains, out-of-sample validation
10. **Support experiment management** -- multi-config comparison, sensitivity analysis, reproducibility
11. **Add observability and diagnostics** -- training visualization, convergence analysis, debugging tools
12. **Comprehensive documentation** -- API docs, tutorials, example cases

## Non-Goals

- Replacing SDDP.jl with a custom SDDP implementation
- Supporting non-linear programming formulations (the scope is LP/MILP within SDDP.jl's framework)
- Building a GUI or web interface (CLI and programmatic API only)
- Supporting Julia versions below 1.10
- Replacing the JSONC + CSV input format (extend, not replace)

## Validation Pipeline Research

### Problem Statement

The current validation pipeline spans 1900+ lines across 15+ files with massive boilerplate. Every entity type requires 5-8 hand-written functions following the same `build_internals -> validate_keys_types -> validate_content -> validate_consistency` 4-step pattern. Many of these functions are trivial stubs (`return true`), and the overall structure entangles three concerns: file resolution (casting), object construction (building), and constraint checking (validation). The dict mutation pattern -- where `d::Dict{String,Any}` is progressively mutated from raw JSON values to typed Julia objects -- makes the data flow hard to reason about and requires dual-phase type checking (before-build and after-build).

This boilerplate will compound as the project adds new entity types (non-controllable generation, energy contracts, pumping stations) and new algorithm options (risk measures, stopping rules, sampling schemes, duality handlers, forward passes, cut types). Without simplification, every new entity will require 5-8 new validator functions, each following the same mechanical pattern.

### Options Evaluated

#### Option A: Declarative Schema with Code Generation (Macro-based)

```julia
@validatable struct Bus
    id::Integer => (required=true, positive=true)
    name::String => (required=true, pattern=r"^[\sa-zA-Z0-9_-]*$")
    deficit_cost::Real => (required=true, positive=true)
end
```

**Performance**: Macros expand at compile time, so runtime cost is zero. However, macro-generated code increases compilation time and the generated method bodies are opaque to `@code_warntype`.

**Maintainability**: Excellent for simple cases. Adding a new entity is one declaration. However, complex validators (e.g., Hydro's cross-referencing of Buses, or the topology DAG check) cannot be expressed in annotation syntax and require escape hatches, fragmenting the declaration model.

**Migration cost**: Very high. Every struct definition must be rewritten. The macro must handle: positional constructors, dict-based constructors, file-casting, kind-factory dispatch, before-build vs. after-build phases, cross-entity dependencies, and CompositeException accumulation. This is essentially writing a mini-framework inside a macro.

**Compatibility with `__kind_factory!`**: Requires the macro to generate the `(d::Dict{String,Any}, e::CompositeException)` constructor signature, which is possible but adds macro complexity.

**Cross-entity support**: Poor without significant escape hatches. The Thermal/Hydro/Line constructors receive `buses::Buses` as an extra argument -- the macro would need to know about arbitrary dependency injection.

**Verdict**: Too complex. The macro becomes a framework-within-a-framework that is harder to debug than the boilerplate it replaces.

#### Option B: Validation Protocol via Multiple Dispatch

```julia
abstract type Validatable end
required_keys(::Type{Bus}) = ["id", "name", "deficit_cost"]
key_types(::Type{Bus}) = Dict("id" => Integer, "name" => String, "deficit_cost" => Real)
validate_content(b::Bus, e::CompositeException) = ...
```

**Performance**: Excellent. Multiple dispatch is Julia's core strength and the compiler optimizes method resolution heavily. All methods are type-stable by construction.

**Maintainability**: Good organization, but still requires per-entity method definitions. Reduces boilerplate for the `keys_types` phase but content and consistency validators remain manual.

**Migration cost**: Medium. Each entity gets a cleaner interface but the actual validation logic is the same, just reorganized.

**Compatibility**: Natural fit -- Julia's type system handles this natively.

**Cross-entity support**: Good via dispatch on tuples or additional arguments.

**Verdict**: Better organization but does not eliminate the fundamental boilerplate. The keys/types validation is the easy part; the content validators are where the real code lives.

#### Option C: Field Descriptor Tables

```julia
const BUS_SCHEMA = [
    FieldRule("id", Integer; required=true, positive=true),
    FieldRule("name", String; required=true, pattern=r"^[\sa-zA-Z0-9_-]*$"),
    FieldRule("deficit_cost", Real; required=true, positive=true),
]
```

**Performance**: Excellent. `FieldRule` is a concrete struct, `Vector{FieldRule}` is a concrete type, and the generic validation loop over rules is type-stable if parameterized correctly. The schema `const` vectors are allocated once at module load time.

**Maintainability**: Excellent. Adding a new entity means defining one const vector and optionally a custom content validator. The keys/types/basic-content validation phases are completely automated. Complex validators (cross-entity, topology) remain as explicit functions, but the simple validators (positive, non-negative, in-range, regex, non-empty) are eliminated.

**Migration cost**: Low-medium. The `FieldRule` infrastructure is a new module. Each entity gets a schema table replacing its `__validate_*_keys_types!` and simple `__validate_*_content!` functions. Complex validators remain unchanged. The migration can be done entity-by-entity without breaking existing code.

**Compatibility**: Full. The schema-driven constructor generates the same `(d::Dict{String,Any}, e::CompositeException)` signature. `__kind_factory!` works unchanged.

**Cross-entity support**: Custom content validators handle this -- the schema handles simple constraints, and cross-entity logic remains explicit.

**Verdict**: Strongest balance of simplicity, expressiveness, and migration cost. Eliminates the mechanical boilerplate while keeping complex logic explicit.

#### Option D: Separate Parse/Validate/Build Phases Completely

Three clean phases: (1) Parse all JSONC/CSV into raw dicts, (2) Validate all raw dicts, (3) Build typed objects.

**Performance**: Negligible overhead from an extra pass. However, phase 2 (validate all raw dicts) cannot check constraints that depend on built objects (e.g., Lines cannot validate their bus_id reference until Buses are built). This forces either duplicating validation or accepting weaker validation in phase 2.

**Maintainability**: Excellent separation of concerns but introduces a new concept (validation context) and requires maintaining the phase boundary.

**Migration cost**: Very high. The entire build pipeline must be restructured. The current interleaved build/validate pattern is deeply embedded -- SystemData builds Buses first, then passes them to Lines/Hydros/Thermals. A full phase separation would require a topological sort of build dependencies and a context-passing mechanism.

**Compatibility**: Breaks `__kind_factory!` which relies on dict mutation during build.

**Cross-entity support**: Requires deferred validation for cross-entity constraints, adding complexity.

**Verdict**: Theoretically clean but impractical given the current architecture. The interleaved build order (Buses -> Lines/Hydros/Thermals) is a real constraint, not an accident.

#### Option E: Hybrid -- Schema Tables + Protocol + Existing Build Order

Combine the best of Options B and C while preserving the existing build order:

1. Define schemas as `FieldRule` tables (Option C) for keys/types/simple-content validation
2. Generic `validate_from_schema` function processes schemas, eliminating per-entity boilerplate for the mechanical parts
3. Use multiple dispatch (Option B) for custom content and consistency validators
4. Preserve the existing `build_internals -> validate -> construct` flow and dict mutation pattern
5. Keep `__kind_factory!` unchanged

**Performance**: Excellent. Schema tables are const vectors of concrete structs. The generic validation function is a tight loop over rules. Custom validators are regular methods -- no overhead.

**Maintainability**: Excellent. New entities define: (a) a schema table, (b) optionally a custom content validator for complex rules, (c) a struct definition. The 5-8 function boilerplate per entity is reduced to 1-2 definitions plus a schema.

**Migration cost**: Low. The schema infrastructure is additive. Entities can be migrated one at a time. The build pipeline is unchanged. Tests continue to pass throughout migration.

**Compatibility**: Full. The dict-based constructor pattern is preserved. `__kind_factory!` works unchanged. CompositeException accumulation works unchanged.

**Cross-entity support**: Custom content validators handle cross-entity dependencies explicitly, same as today but with less surrounding boilerplate.

### Chosen Approach: Option E (Hybrid Schema Tables + Protocol)

Option E is selected because it:

1. **Eliminates the largest source of boilerplate** -- the per-entity `__validate_*_keys_types!` functions and simple content validators (positive, non-negative, in-range, regex) become declarative schema entries
2. **Preserves the existing architecture** -- the build order, dict mutation pattern, `__kind_factory!`, and CompositeException accumulation are all unchanged
3. **Enables incremental migration** -- entities can be migrated one at a time without breaking anything
4. **Is type-stable and performant** -- `FieldRule` is a concrete struct, schema vectors are const, the generic validation function is a tight loop
5. **Keeps complex validation explicit** -- cross-entity references (Lines -> Buses), topology checks (Hydro DAG), and stochastic process validation remain as explicit functions that are clear and testable
6. **Reduces the cost of adding new entities** -- Epic 05 (non-controllable generation, energy contracts, pumping stations) will benefit directly from the schema infrastructure

### Architecture Impact

The validation simplification adds a new module `src/Utils/schema.jl` containing:

- `FieldRule` struct: declarative field descriptor with name, type, and constraint predicates
- `validate_schema!`: generic function that processes a schema against a dict, performing keys, types, and simple content validation in one pass
- `validate_and_build!`: convenience function wrapping the 4-step pattern with schema-driven phases 1-2 and custom function phases 3-4
- Predicate constructors: `positive()`, `non_negative()`, `in_range(lo, hi)`, `matches(regex)`, `non_empty()`, etc.

The existing `validation-utils.jl` remains for DataFrame validation, file validation, and the `__parse_as_type!` infrastructure. The new schema module calls into `__parse_as_type!` for type conversion.

## Architecture Overview

### Current State (main branch)

```
SDDPlab.jl
  +-- Core (types, variables, files)
  +-- Utils (validation, reading)
  +-- StochasticProcess (Naive, AutoRegressive)
  +-- Algorithm (ScenarioGraph, Horizon)
  +-- System (Bus, Line, Hydro, Thermal)
  +-- Scenarios (Inflow, Load)
  +-- Outputs (CSV, Parquet formatting)
  +-- Tasks (Policy, Simulation, model building)
  +-- Inputs (config parsing)
  +-- Main.jl (entry point)
```

### Target State (abstract-engine branch, completed)

```
SDDPlab.jl
  +-- Lab (abstract types, tasks interface, variables, files, IO)
  +-- Utils (validation, reading, schema)
  +-- StochasticProcess (Naive, AutoRegressive, [new models])
  +-- System (Bus, Line, Hydro, Thermal, [new elements])
  +-- Scenarios (Graph, Inflow, Load)
  +-- Inputs (config parsing)
  +-- Engines/
  |     +-- Engines.jl (abstract engine orchestration)
  |     +-- sddp.jl (SDDP engine entry)
  |     +-- sddp/ (build, train, simulate, save, load)
  +-- study.jl + study-validators.jl (Study entry point)
```

### Key Design Decisions

1. **Engine abstraction**: The `Engine <: abstract type` pattern allows future engines (e.g., deterministic equivalent, Benders) without changing the study orchestration layer
2. **Kind/Params factory pattern**: All polymorphic types (risk measures, stopping criteria, parallel schemes, stochastic processes, load scenarios) use `{"kind": "TypeName", "params": {...}}` in JSONC, resolved via `__kind_factory!` at parse time
3. **Validation pipeline**: Every type follows `build_internals -> validate_keys_types -> validate_content -> validate_consistency` 4-step construction, with the keys/types and simple content phases now automated by schema tables
4. **InputModule vector**: System and Scenarios data are collected as `Vector{InputModule}`, passed to engine methods, and extracted by type via `get_input_module`
5. **Schema-driven validation**: Field schemas declared as `FieldRule` tables replace hand-written `__validate_*_keys_types!` and simple `__validate_*_content!` functions. Complex validation remains explicit.

## Technical Approach

### Tech Stack

- **Language**: Julia >= 1.10
- **Core dependency**: SDDP.jl (Oscar Dowson's package)
- **Optimization**: JuMP.jl + HiGHS/GLPK solvers
- **Data I/O**: CSV.jl, DataFrames.jl, Parquet.jl, JSON.jl
- **Stochastic modeling**: Distributions.jl, Copulas.jl
- **Graph topology**: Graphs.jl
- **Style**: Blue formatting (.JuliaFormatter.toml)
- **Testing**: Test stdlib + GLPK + Suppressor

### Component/Module Breakdown

| Module            | Responsibility                                                                     | Epics      | Primary Agent       |
| ----------------- | ---------------------------------------------------------------------------------- | ---------- | ------------------- |
| Lab               | Abstract types, interface contracts                                                | 1          | hpc-julia-developer |
| Utils/schema      | Declarative field schemas and generic validation                                   | 1          | hpc-julia-developer |
| Engines/sddp      | Concrete SDDP engine (build/train/simulate)                                        | 1, 2, 3, 4 | both                |
| System            | Power system entities (Bus, Line, Hydro, Thermal, NonControllable, Contract, Pump) | 1, 5       | both                |
| Scenarios         | Graph topology, inflow/load/availability scenarios                                 | 1, 5, 6    | sddp-specialist     |
| StochasticProcess | Stochastic models (Naive, AR, Markov, Multivariate)                                | 7          | sddp-specialist     |
| Inputs            | JSONC/CSV config parsing                                                           | 1, 2, 5, 6 | hpc-julia-developer |
| Utils             | Validation, reading, units                                                         | 1, 3       | hpc-julia-developer |
| Experiments       | Multi-config comparison, sensitivity analysis                                      | 8          | hpc-julia-developer |
| Diagnostics       | Training visualization, convergence analysis                                       | 9          | sddp-specialist     |

### Data Flow

```
JSONC config files
       |
       v
  read_study() --> Study(InputsData, Engine)
       |
       v
  build(study, optimizer) --> Model (SDDPModel wrapping SDDP.PolicyGraph)
       |
       v
  train(study, model) --> PolicyTaskArtifact
       |
       v
  simulate(study, model) --> SimulationTaskArtifact
       |
       v
  save_policy / save_simulation --> Parquet/CSV files
```

### Testing Strategy

- **Unit tests**: Every type constructor with valid/invalid inputs, every validator function, schema infrastructure
- **Integration tests**: Full study read -> build -> train -> simulate -> save pipeline
- **Regression tests**: Existing example cases (1dtoy, 1dsin, 1dsin_ar) must produce identical results
- **New example tests**: Each new feature gets a minimal example case

### Test Execution Protocol

**CRITICAL**: Agents MUST follow these rules when running tests. The full test suite takes ~4 minutes and includes SDDP training runs that can hang indefinitely. Running without filters or timeouts will block the session.

#### 1. Always use TEST_FILTER to run only relevant tests

The `test/runtests.jl` file supports a `TEST_FILTER` environment variable that filters test files by substring match. After implementing a ticket, run ONLY the test files relevant to your changes:

```bash
# Run only tests matching a pattern (fast, seconds)
export TEST_FILTER="test-engines" && julia --project -e 'using Pkg; Pkg.test()'

# Run tests for a specific new test file
export TEST_FILTER="test-threaded" && julia --project -e 'using Pkg; Pkg.test()'

# Run multiple related patterns (comma NOT supported — use broader substring)
export TEST_FILTER="test-sddp" && julia --project -e 'using Pkg; Pkg.test()'
```

**NEVER** run the full test suite (`julia --project -e 'using Pkg; Pkg.test()'` without TEST_FILTER) unless explicitly asked by the user.

#### 2. Always use a timeout

All test commands MUST use the Bash tool's `timeout` parameter (in milliseconds). Recommended values:

| Scope                 | Timeout (ms) | Notes                                    |
| --------------------- | ------------ | ---------------------------------------- |
| Filtered unit tests   | 120000       | 2 minutes — sufficient for any unit test |
| Filtered integration  | 180000       | 3 minutes — includes SDDP train/simulate |
| Full suite (if asked) | 360000       | 6 minutes — only when user requests it   |

#### 3. Solver thread safety

- **GLPK is NOT thread-safe** — tests using `SDDP.Threaded()` MUST use HiGHS as the solver
- Standard (non-threaded) tests use GLPK
- If a test SIGABRTs, the first thing to check is whether GLPK is being used with threading

#### 4. Test file isolation

- Adding tests to large existing test files (e.g., `test-engines.jl`) has caused unexplained SIGABRTs
- Prefer creating **separate test files** for new feature areas (e.g., `test-threaded.jl`, `test-build-optimizations.jl`)
- New test files are automatically discovered by `runtests.jl` via `__list_test_files`

## Phases & Milestones

| Phase | Epic                              | Duration  | Milestone                                                           | Primary Agent(s)                                 |
| ----- | --------------------------------- | --------- | ------------------------------------------------------------------- | ------------------------------------------------ |
| 1     | Stabilize Engine Abstraction      | 5-7 weeks | `abstract-engine` merged, validation simplified, all TODOs resolved | hpc-julia-developer                              |
| 2     | Algorithm Flexibility             | 4-5 weeks | All SDDP.jl knobs exposed via JSONC config                          | sddp-specialist + hpc-julia-developer (parallel) |
| 3     | Units & LP Conditioning           | 3-4 weeks | Unit tracking + automatic rescaling working                         | hpc-julia-developer + sddp-specialist            |
| 4     | Parallelization & Performance     | 3-4 weeks | Threading + distributed computing enabled                           | hpc-julia-developer                              |
| 5     | Enhanced System Elements          | 3-4 weeks | Non-controllable gen, contracts, pumping stations modeled           | sddp-specialist + hpc-julia-developer            |
| 6     | Subproblem Structure & Stochastic | 4-5 weeks | Time duration, load blocks, inflow non-negativity                   | sddp-specialist                                  |
| 7     | Advanced Stochastic Modeling      | 3-4 weeks | Multivariate processes, Markov chains, out-of-sample validation     | sddp-specialist                                  |
| 8     | Experiment Management             | 3-4 weeks | Multi-config comparison, sensitivity analysis                       | hpc-julia-developer                              |
| 9     | Observability & Diagnostics       | 2-3 weeks | Training visualization, convergence analysis                        | sddp-specialist                                  |
| 10    | Documentation & Examples          | 2-3 weeks | Comprehensive docs, tutorials, examples                             | both                                             |

### Parallelization Opportunities

Within Epic 02, tickets 010-015 are mutually independent (each adds a different algorithm knob). This enables:

- **sddp-specialist** can work on tickets 010, 011, 013, 014, 015 in parallel batches
- **hpc-julia-developer** can work on ticket 012 (sampling schemes, more infrastructure-heavy)
- Ticket 016 (wiring) waits for all 010-015 to complete, then either agent can handle it

Within later epics, the `sddp-specialist` and `hpc-julia-developer` can work on independent epics concurrently once dependencies allow (e.g., ticket-030 inflow non-negativity is independent of ticket-029 load blocks within Epic 06, enabling parallel work).

## Risk Analysis

| Risk                                                              | Impact | Likelihood | Mitigation                                                         |
| ----------------------------------------------------------------- | ------ | ---------- | ------------------------------------------------------------------ |
| SDDP.jl API changes between versions                              | High   | Low        | Pin SDDP.jl version in Project.toml compat                         |
| Graph validation complexity (cyclic graphs, Markov states)        | Medium | Medium     | Incremental validation: linear first, then cyclic                  |
| Load representation refactor breaks backward compatibility        | High   | Medium     | Maintain DeterministicLoad as default, add stochastic as new kind  |
| Parallelization introduces thread-safety issues in SAA generation | Medium | Medium     | Isolate RNG per thread, test with ThreadSanitizer                  |
| Unit conversion introduces floating-point drift                   | Low    | Medium     | Use exact rational arithmetic for conversion factors               |
| Agent coordination overhead on shared files                       | Medium | Low        | Clear ticket boundaries with no overlapping file modifications     |
| Schema migration introduces regressions in validation behavior    | Medium | Medium     | Migrate one entity at a time with full regression tests after each |
| Schema infrastructure adds compilation overhead                   | Low    | Low        | FieldRule is a concrete struct; no generated functions or closures |
| Block decomposition enlarges LP and slows training                | Medium | Medium     | Benchmark parallel vs chronological; provide single-block default  |
| Time duration conversion breaks existing example cases            | Medium | Medium     | Backward-compatible default (implicit unit time when no blocks)    |

## Success Metrics

1. All existing example cases produce identical numerical results after each epic
2. Every SDDP.jl algorithm knob has at least one test exercising it
3. Test coverage >= 80% for new code
4. All tests pass with GLPK on Julia 1.10+
5. Full pipeline (read -> build -> train -> simulate -> save) works for all supported configurations
6. Documentation covers every user-facing type and function
7. Validation pipeline code reduced by at least 40% in line count after schema migration
8. Adding a new simple entity (no cross-entity dependencies) requires only a schema table and struct definition
