# ticket-041 Write API Reference Documentation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify SDDP-specific API documentation accuracy)

## Context

### Background

SDDPlab.jl has grown from a simple SDDP wrapper to a comprehensive experimentation laboratory over the course of 9 epics and 40 tickets. The package now exports 80+ symbols across 6 modules (`Lab`, `System`, `Scenarios`, `StochasticProcess`, `Engines`, `Experiments`), including types, functions, and constants. However, most exported symbols lack docstrings, and the existing documentation site (a skeleton Documenter.jl setup in `docs/`) is outdated -- it references the old `main()` API and the pre-refactoring file structure.

This ticket sets up a proper Documenter.jl documentation build and adds comprehensive docstrings to all public types and functions, enabling both in-REPL `?help` queries and a browsable HTML documentation site.

### Relation to Epic

This is the first ticket in Epic 10 (Documentation & Examples). It creates the foundation that ticket-042 (configuration reference) and ticket-043 (tutorial examples) will link to. However, all three tickets operate on different file areas and can be executed in parallel.

### Current State

- `docs/` directory exists with a skeleton Documenter.jl setup:
  - `docs/Project.toml` lists `Documenter` and `SDDPlab` as dependencies
  - `docs/make.jl` has a basic `makedocs` call with `modules = [SDDPlab]` commented out and only 2 pages ("Introduction" `index.md` and "Getting Started" `man/getting_started.md`)
  - `docs/src/index.md` has a basic introduction paragraph
  - `docs/src/man/getting_started.md` is outdated (references old `main()` API, old file structure with `tasks.jsonc`/`algorithm.jsonc`)
  - `docs/src/assets/` has `favicon.ico` and `logo.svg`
- Most exported symbols have NO docstrings. A few have minimal ones (e.g., `get_id`, `get_params`, `length` in `System.jl`; experiment types in `Experiments/types.jl` and functions in `Experiments/runner.jl`, `sensitivity.jl`, `comparison.jl`, `reproducibility.jl`).
- The `SDDPlab` module (`src/SDDPlab.jl`) exports: `read_study`, `build`, `train`, `save_policy`, `load_policy`, `simulate`, `save_simulation`, `debug`, `DebugConfig`, `CSVFormat`, `ParquetFormat`, `run_experiment`, `read_experiment_config`, `ExperimentConfig`, `ExperimentResult`, `run_sensitivity`, `read_sensitivity_config`, `SensitivityConfig`, `SensitivityParameter`, `SensitivityResult`, `aggregate_experiment_results`, `write_comparison`, `compare_configs`, `ComparisonResult`, `ConfigSummary`, `EnvironmentSnapshot`, `capture_environment`, `hash_config`, `write_run_metadata`, `verify_reproducibility`

## Specification

### Requirements

1. **Update `docs/make.jl`**:
   - Uncomment `modules = [SDDPlab]`
   - Define a comprehensive page structure covering all 6 modules
   - Pages should be organized by domain: API Reference > Core Pipeline, System Elements, Scenarios & Stochastic Processes, Engine Configuration, Experiments, Observability
   - Set `checkdocs = :exports` so the build warns about undocumented exports

2. **Update `docs/src/index.md`**:
   - Rewrite the introduction to reflect the current state of the package (not the old `main()` API)
   - Include a table of contents linking to all documentation sections

3. **Update `docs/src/man/getting_started.md`**:
   - Replace the outdated `main()` usage with the current `read_study` -> `build` -> `train` -> `simulate` pipeline
   - Update the file structure example to match the current `main.jsonc` format (no `tasks.jsonc`, no `algorithm.jsonc`; uses `engine.kind`/`engine.params` structure)
   - Show correct solver configuration (HiGHS via config, not GLPK.Optimizer argument)

4. **Add docstrings to all exported symbols** in source files. For each symbol, the docstring must include:
   - One-line summary
   - Longer description (what it does, when to use it)
   - Fields (for structs) or Arguments (for functions)
   - Return type (for functions)
   - Example usage (at least a minimal code snippet)
   - Cross-references to related types/functions using ``[`OtherType`](@ref)`` syntax

5. **Create API reference pages** in `docs/src/api/`:
   - `pipeline.md` -- `read_study`, `build`, `train`, `simulate`, `save_policy`, `load_policy`, `save_simulation`, `debug`, `validate`, `save_validation`, `Study`
   - `system.md` -- `SystemData`, `Bus`, `Buses`, `Hydro`, `Hydros`, `Thermal`, `Thermals`, `NonControllable`, `NonControllables`, `EnergyContract`, `EnergyContracts`, `PumpingStation`, `PumpingStations`, `Line`, `Lines`, `get_system`, getter functions
   - `scenarios.md` -- `ScenariosData`, `Graph`, `Node`, `Edge`, `Block`, `BlockConfig`, `InflowScenarios`, `AbstractMarkovChain`, `NoMarkovChain`, `MarkovChainConfig`, scenario helper functions
   - `stochastic.md` -- `Naive`, `AutoRegressive`, `VectorAutoRegressive`, `generate_saa`, `AbstractStochasticProcess`
   - `engine.md` -- `SDDPEngine`, `SDDPPolicyTaskDefinition`, `SDDPSimulationTaskDefinition`, `Convergence`, all `StoppingCriteria` subtypes, all `RiskMeasure` subtypes, all `ParallelScheme` subtypes, all `SamplingScheme` subtypes, all `DualityHandler` subtypes, all `ForwardPassStrategy` subtypes, all `CutType` subtypes, `ScalingMode`/`NoScaling`/`AutoScaling`, `SolverConfig`, `DiagnosticsConfig`, `DebugConfig`, `TrainingLogConfig`, `InflowNonNegativity` subtypes, `OutOfSampleValidation`
   - `experiments.md` -- `run_experiment`, `read_experiment_config`, `ExperimentConfig`, `ExperimentResult`, `run_sensitivity`, `read_sensitivity_config`, `SensitivityConfig`, `SensitivityParameter`, `SensitivityResult`, `aggregate_experiment_results`, `write_comparison`, `compare_configs`, `ComparisonResult`, `ConfigSummary`
   - `observability.md` -- `TrainingLog`, `TrainingLogEntry`, `EnvironmentSnapshot`, `capture_environment`, `hash_config`, `write_run_metadata`, `verify_reproducibility`, convergence analysis functions (if exported)
   - `variables.md` -- All variable symbol constants (`LOAD`, `DEFICIT`, `THERMAL_GENERATION`, etc.) and output format types (`CSVFormat`, `ParquetFormat`, `TaskResultsFormat`)

6. Each API reference page should use `@docs` blocks to pull docstrings from source, grouped by logical subsection with brief prose introductions.

### Inputs/Props

- Source files containing the exported symbols (see Key Files to Modify below)
- Existing `docs/` skeleton

### Outputs/Behavior

- Running `julia --project=docs/ docs/make.jl` from the repo root should produce a complete HTML documentation site in `docs/build/` with no docstring warnings
- All exported symbols should have docstrings accessible via `?SymbolName` in the Julia REPL
- The documentation build should complete without errors

### Error Handling

- If a symbol cannot be documented because its role is unclear, add a minimal docstring with a TODO comment and flag it in the PR description
- If `Documenter.jl` warns about cross-references that cannot be resolved, fix the reference or remove it

## Acceptance Criteria

- [ ] Given the repository, when running `julia --project=docs/ docs/make.jl`, then the build completes without error and produces `docs/build/index.html`
- [ ] Given the built documentation, when navigating to the API Reference section, then every exported symbol from `SDDPlab` has a rendered docstring page
- [ ] Given a Julia REPL with `using SDDPlab`, when typing `?read_study`, then a meaningful docstring is displayed
- [ ] Given a Julia REPL with `using SDDPlab`, when typing `?SDDPEngine`, then a docstring with all 7 fields, their types, and descriptions is displayed
- [ ] Given the `docs/src/man/getting_started.md` page, when reading it, then it describes the current `read_study` -> `build` -> `train` -> `simulate` pipeline (not the old `main()` API)
- [ ] Given the `docs/make.jl` configuration, when `checkdocs = :exports` is set, then the build produces no "missing docstring" warnings for exported symbols

## Implementation Guide

### Suggested Approach

1. **Start with the `docs/make.jl` update**: Define the full page tree. Uncomment `modules = [SDDPlab]`. Add all the API reference pages to the `pages` array.

2. **Create the API reference page files** in `docs/src/api/`. Each page should have:
   - A title and brief introduction paragraph
   - `@docs` blocks for each symbol, grouped by logical subsection
   - Example:

     ````markdown
     # Core Pipeline

     The core pipeline functions are the primary entry points for using SDDPlab.

     ## Reading a Study

     ```@docs
     read_study
     ```
     ````

     ## Building the Model

     ```@docs
     build
     ```

     ```

     ```

3. **Add docstrings to source files**, working module by module:
   - `src/study.jl`: `Study`, `read_study`, `build`, `train`, `save_policy`, `simulate`, `save_simulation`, `debug`, `diagnose`, `validate`, `save_validation`
   - `src/Lab/Lab.jl` + `src/Lab/types.jl` + `src/Lab/files.jl` + `src/Lab/variables.jl`: All Lab exports (types, constants, format types)
   - `src/System/System.jl` + entity files: All system entity types and getter functions
   - `src/Scenarios/Scenarios.jl` + subfiles: All scenario types and helpers
   - `src/StochasticProcess/StochasticProcess.jl` + subfiles: Stochastic process types
   - `src/Engines/Engines.jl` + `src/Engines/sddp/input.jl`: All engine types and configuration types
   - `src/Experiments/*.jl`: Already has docstrings -- review and improve if needed

4. **Update `docs/src/index.md`** with a proper overview and table of contents.

5. **Update `docs/src/man/getting_started.md`** to reflect the current API.

6. **Test the build**: Run `julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'` then `julia --project=docs/ docs/make.jl` and verify no warnings.

### Key Files to Modify

**Documentation files (create or update):**

- `docs/make.jl` -- update page structure, uncomment modules
- `docs/src/index.md` -- rewrite introduction
- `docs/src/man/getting_started.md` -- update to current API
- `docs/src/api/pipeline.md` -- NEW: core pipeline API reference
- `docs/src/api/system.md` -- NEW: system elements API reference
- `docs/src/api/scenarios.md` -- NEW: scenarios API reference
- `docs/src/api/stochastic.md` -- NEW: stochastic processes API reference
- `docs/src/api/engine.md` -- NEW: engine configuration API reference
- `docs/src/api/experiments.md` -- NEW: experiment management API reference
- `docs/src/api/observability.md` -- NEW: observability tools API reference
- `docs/src/api/variables.md` -- NEW: variable symbols and output formats reference

**Source files (add docstrings):**

- `src/study.jl` -- docstrings for `Study`, `read_study`, `build`, `train`, `simulate`, etc.
- `src/Lab/types.jl` -- docstrings for `Engine`, `Model`, `PolicyTaskDefinition`, etc.
- `src/Lab/variables.jl` -- docstrings for variable symbol constants
- `src/Lab/files.jl` -- docstrings for output filename constants
- `src/Lab/io.jl` -- docstrings for format types
- `src/System/System.jl` -- docstrings for entity types and getter functions
- `src/Scenarios/Scenarios.jl` -- docstrings for scenario types
- `src/Scenarios/blocks.jl` -- docstrings for `Block`, `BlockConfig`
- `src/Scenarios/markov.jl` -- docstrings for Markov chain types
- `src/StochasticProcess/StochasticProcess.jl` -- docstrings for process types
- `src/Engines/Engines.jl` -- docstrings for all engine configuration types
- `src/Engines/sddp/convergence_analysis.jl` -- docstrings for convergence analysis functions

### Patterns to Follow

- Julia docstring format: triple-quoted string immediately before the function/type definition
- Use `# Fields` for struct docstrings, `# Arguments` for function docstrings
- Use `# Examples` with `jldoctest or `julia blocks
- Use `See also: [`OtherType`](@ref)` for cross-references
- Follow the existing docstring style in `src/Experiments/types.jl` (which already has good docstrings with Fields, Examples sections)
- Documenter.jl `@docs` blocks use the unqualified name (e.g., `read_study`, not `SDDPlab.read_study`)

### Pitfalls to Avoid

- Do NOT include private functions (prefixed with `__` or `_`) in the API reference pages
- Do NOT add `Documenter` to the main `Project.toml` -- it belongs only in `docs/Project.toml`
- Do NOT change the `deploydocs` configuration -- keep the existing GitHub Pages setup
- Docstrings for abstract types with multiple subtypes should list all subtypes
- When documenting `const` symbols like `LOAD = Symbol("LOAD")`, use a string docstring above the constant, not a function-style docstring
- The `docs/Project.toml` may need updating to add `SDDPlab` as a dev dependency (via path) for the build to find the module. Check if it needs `[sources]` section with `SDDPlab = {path = ".."}` for Julia >= 1.10.

## Testing Requirements

### Unit Tests

- No new unit tests required (this is a documentation-only ticket)

### Integration Tests

- Verify `julia --project=docs/ docs/make.jl` completes without error
- Verify the build produces `docs/build/index.html` and pages for all API reference sections
- Verify `checkdocs = :exports` produces no "missing docstring" warnings

### E2E Tests

- Not applicable

## Dependencies

- **Blocked By**: None (Epic 09 complete; all source code is finalized)
- **Blocks**: None (ticket-042 and ticket-043 are independent)

## Effort Estimate

**Points**: 4
**Confidence**: Medium (the scope is clear but adding docstrings to 80+ symbols is mechanical but time-consuming; the existing Experiments module docstrings provide a good template)
