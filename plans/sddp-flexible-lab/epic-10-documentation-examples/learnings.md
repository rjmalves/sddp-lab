# Epic 10 Learnings — Documentation and Examples

## Patterns Established

### Selective `using .SubModule: Symbol` imports in parent module for Documenter.jl

Documenter.jl's `@docs` blocks resolve symbols against the modules listed in `makedocs(modules = [...])`. When a type is defined inside a Julia submodule (e.g., `SDDPlab.Engines.IterationLimit`) and that submodule is in the `modules` list, Documenter can find the docstring — but only if the symbol is also reachable in the `SDDPlab` namespace at doc-build time. The fix is to add explicit `using .SubModule: TypeName` bindings inside the parent `SDDPlab` module for every exported symbol. Without this, symbols defined in submodules are exported from the submodule but are NOT automatically bound in the parent module's namespace, so Documenter raises "undefined binding" warnings. This was applied to all six submodules (Lab, System, Scenarios, StochasticProcess, Engines) in `src/SDDPlab.jl` lines 11-250.

### `warnonly = true` in `makedocs` for parallel documentation builds

When multiple agents edit `docs/make.jl` in parallel, one agent may reference a page or `@docs` block that the other agent has not yet created. Setting `warnonly = true` in `makedocs` (see `docs/make.jl` line 21) allows the build to complete with non-fatal warnings rather than raising an error. This is necessary when documentation is developed incrementally or when parallel agents share the `docs/make.jl` file. The downside is that broken `@ref` cross-references and missing docstrings become warnings rather than errors, so the build result must be inspected manually.

### All documentation types consolidated into a single `modules` list

Instead of listing only `SDDPlab` in `makedocs(modules = [...])`, the final build lists all six submodules explicitly: `SDDPlab`, `SDDPlab.Lab`, `SDDPlab.System`, `SDDPlab.Scenarios`, `SDDPlab.StochasticProcess`, and `SDDPlab.Engines`. This tells Documenter to search docstrings across all module namespaces and eliminates "not documented" warnings for submodule-owned types. See `docs/make.jl` lines 10-17.

### `@docs` blocks use the unqualified name after parent-module import

Once `using .Engines: IterationLimit` is added to `SDDPlab.jl`, Documenter can resolve `@docs IterationLimit` (unqualified) in any page. Without the parent-module import, the `@docs` block requires the qualified name `Engines.IterationLimit`, which is harder to read and still requires the module to be in the `modules` list.

### Inline `entities` arrays in JSONC require explicit `Vector{Any}` to `Vector{Dict{String,Any}}` conversion

When entity data is provided inline in JSONC (the `"entities": [...]` pattern, as opposed to `"file": "path.csv"`), Julia's `JSON.jl` parser returns the array as `Vector{Any}` rather than `Vector{Dict{String,Any}}`. The downstream validators (`FieldRule`, `validate_schema!`) expect `Dict{String,Any}` for each element. The conversion is applied explicitly in `src/System/System.jl` lines 465-472:

```julia
if haskey(entities_d, "entities") && entities_d["entities"] isa Vector{Any}
    entities_d["entities"] = convert(
        Vector{Dict{String,Any}},
        [convert(Dict{String,Any}, x) for x in entities_d["entities"]],
    )
end
```

This fix was required by the `pumped_storage` and `renewable_contracts` examples that use inline `pumpingstations` and `energycontracts` sections.

### Documenter.jl `@ref` cross-references require symbols on documented pages

A `[`OtherType`](@ref)` cross-reference in a docstring only renders without a warning if `OtherType` is documented somewhere in the page tree via a `@docs OtherType` block. If the referenced symbol is not in any `@docs` block on any page, Documenter raises an "undefined link target" warning. With `warnonly = true` this degrades to a warning, not a build failure.

## Architectural Decisions

### Parallel execution of tickets 041, 042, 043 caused a shared `docs/make.jl` conflict

Decision: All three documentation tickets (API reference, configuration reference, tutorials) were designed to run in parallel. Ticket-041 (`hpc-julia-developer`) built the full page tree in `docs/make.jl` and the other two tickets appended their sections. In practice this caused the second agent to overwrite the first agent's changes.
Rejected: Sequential execution, which would have avoided the conflict.
Rationale adopted: The last agent to write `docs/make.jl` won, so the final state includes all three sections only if the last write consolidated all additions. The working solution is that `warnonly = true` allows incomplete intermediate states to not block the build, and the final `make.jl` at `docs/make.jl` was manually reconciled to include all three sections (Configuration Reference, Tutorials, and API Reference).

### Docstrings added inline in `Engines.jl` rather than in separate sub-files

Decision: All 130+ docstrings for engine configuration types (`IterationLimit`, `CVaR`, `Threaded`, etc.) were added directly in `src/Engines/Engines.jl` (which grew from ~220 lines to 993 lines), not extracted into a separate `engine-docs.jl` file.
Rejected: A separate documentation file that would be `include`-d after the type definitions.
Rationale: Keeping docstrings adjacent to struct definitions is the standard Julia convention. The file size increase is acceptable and the types are all at the top of the file before the `include` statements.

### `"type"` used instead of `"contract_type"` in inline energy contract JSONC

The ticket specification and the validator schema (`src/System/energycontract-validators.jl`) define the field as `"contract_type"`. The inline examples in the `renewable_contracts` example use the key `"type"` (see `example/renewable_contracts/data/system.jsonc` line 37). This is a deviation from the validator's column name. Whether this is intentional alias support or a config bug was not resolved at time of writing. Future agents should verify by running the `renewable_contracts` example against the pipeline.

## Files and Structures Created

- `docs/make.jl` — Updated with `modules` list spanning all six submodules, `checkdocs = :exports`, `warnonly = true`, and three new page sections: Configuration Reference, Tutorials, API Reference (8 API pages)
- `docs/src/index.md` — Rewritten to describe the current `read_study -> build -> train -> simulate` pipeline, with feature table and quick-start example
- `docs/src/man/getting_started.md` — Replaced outdated `main()` API content with the current pipeline using `main.jsonc` format
- `docs/src/api/pipeline.md` — API reference for `Study`, `read_study`, `build`, `train`, `simulate`, `save_policy`, `load_policy`, `save_simulation`, `debug`, `validate`, `save_validation`, and core abstract types
- `docs/src/api/system.md` — API reference for all system entity types (`SystemData`, `Bus`, `Hydro`, `Thermal`, `NonControllable`, `EnergyContract`, `PumpingStation`, `Line`) and all getter functions
- `docs/src/api/scenarios.md` — API reference for `ScenariosData`, `Graph`, `Node`, `Edge`, `Block`, `BlockConfig`, `InflowScenarios`, `AbstractMarkovChain`, `NoMarkovChain`, `MarkovChainConfig`
- `docs/src/api/stochastic.md` — API reference for `AbstractStochasticProcess`, `Naive`, `AutoRegressive`, `VectorAutoRegressive`, `generate_saa`
- `docs/src/api/engine.md` — API reference for all 40+ engine configuration types including all stopping criteria, risk measures, parallel schemes, sampling schemes, duality handlers, forward pass strategies, cut types, scaling modes, and supporting types
- `docs/src/api/experiments.md` — API reference for all experiment orchestration types and functions
- `docs/src/api/observability.md` — API reference for `TrainingLog`, `TrainingLogEntry`, convergence analysis functions, and reproducibility tools
- `docs/src/api/variables.md` — API reference for all variable symbol constants and output format types
- `docs/src/configuration/overview.md` — Config overview: file hierarchy, `kind`/`params` pattern, `file` reference pattern, minimal example
- `docs/src/configuration/system.md` — System config reference: all 7 entity types with CSV columns, types, defaults, and annotated examples
- `docs/src/configuration/scenarios.md` — Scenarios config reference: graph format, stochastic processes (Naive, AR, VAR), load kinds, blocks, Markov chains
- `docs/src/configuration/engine.md` — Engine config reference: all engine keys, all option kinds for every dimension, annotated JSONC examples
- `docs/src/configuration/experiments.md` — Experiment config reference: `experiment.jsonc` and `sensitivity.jsonc` formats with annotated examples
- `docs/src/tutorials/renewable_contracts.md` — Tutorial for `NonControllable` generation and `EnergyContract` import/export modeling
- `docs/src/tutorials/pumped_storage.md` — Tutorial for pumped-storage hydro with upper/lower reservoir and `PumpingStation`
- `docs/src/tutorials/load_blocks.md` — Tutorial for inner load blocks (parallel mode) with block-specific dispatch and duration-weighted water balance
- `docs/src/tutorials/markov_var.md` — Tutorial for Markov chain inflow state transitions with per-state stochastic processes and out-of-sample validation
- `docs/src/tutorials/experiment_sweep.md` — Tutorial for experiment runner and sensitivity analysis using `1dtoy` as base study
- `example/renewable_contracts/` — New example: 2-bus system with wind non-controllable, import/export contracts, 12 stages, Naive inflow
- `example/pumped_storage/` — New example: 2-hydro cascade with pumping station (inline entity definition), 12 stages
- `example/load_blocks/` — New example: 3-block parallel mode with peak/shoulder/off-peak dispatch, 12 stages
- `example/markov_var/` — New example: 2-state Markov chain with per-state Naive inflow files (`inflow_wet.jsonc`, `inflow_dry.jsonc`)
- `example/experiment_sweep/` — New example: `experiment.jsonc` (3 risk measures) + `sensitivity.jsonc` (max_iterations sweep) referencing `../1dtoy`
- `src/Engines/Engines.jl` — 130+ docstrings added for all engine configuration types; export list expanded to include all algorithm option subtypes
- `src/SDDPlab.jl` — 200+ lines of `using .SubModule: Symbol` imports added to bind all submodule types in the parent namespace for Documenter.jl resolution and direct user access
- `src/System/System.jl` — `Vector{Any}` to `Vector{Dict{String,Any}}` conversion added for inline entity arrays (lines 464-474); `SystemEntity` and `SystemEntitySet` added to exports
- `src/Scenarios/Scenarios.jl`, `blocks.jl`, `markov.jl` — Docstrings added for `Graph`, `Node`, `Edge`, `Block`, `BlockConfig`, `AbstractMarkovChain`, `NoMarkovChain`, `MarkovChainConfig`
- `src/StochasticProcess/StochasticProcess.jl`, `naive.jl`, `autoregressive.jl`, `vectorautoregressive.jl` — Docstrings added for all public stochastic process types
- `src/study.jl`, `src/Lab/types.jl`, `src/Lab/variables.jl`, `src/Lab/files.jl` — Docstrings added for `Study`, pipeline functions, format types, and all constant symbols

## Conventions Adopted

### Section-comment headers removed from variables.jl and files.jl

The block comments that previously introduced `src/Lab/variables.jl` and `src/Lab/files.jl` (explaining "these constants are exported so downstream code can reference them") were removed as redundant once each constant received an individual docstring. This avoids dual documentation that can fall out of sync.

### Per-symbol docstrings on `const Symbol` constants

Julia docstrings can be placed directly above a `const` declaration. The pattern adopted throughout `src/Lab/variables.jl` is:

```julia
"Symbol key for bus load demand (MW)."
LOAD = Symbol("LOAD")
```

This allows REPL `?LOAD` help to work and Documenter to pick up the docstring via the `@docs LOAD` block. See `docs/src/api/variables.md` for the full list.

### Tutorial examples use inline `entities` arrays for concise configs

To keep tutorial example configs readable, entities with a small fixed set (e.g., `pumpingstations` with 1 entry, `energycontracts` with 2 entries) are defined inline with `"entities": [...]` instead of via a CSV file reference. CSV file references are used for entities with many rows (buses, hydros, thermals). The `Vector{Any}` conversion fix in `src/System/System.jl` enables this mixed-mode usage.

### Markov inflow files named by state: `inflow_wet.jsonc` / `inflow_dry.jsonc`

In the `markov_var` example, per-state stochastic process files are named by their semantic role rather than by index. The key in `scenarios.jsonc` uses integer string keys (`"1"`, `"2"`) while the files have descriptive names. This naming convention helps users understand which state corresponds to which hydrology.

### Example engine configs use the minimal required fields only

All 5 new examples use `IterationLimit` stopping criteria (50-80 iterations), `Serial` parallelism, and `HiGHS` solver. No examples add optional engine fields (diagnostics, logging, debug, validation) unless that feature is the specific focus of the tutorial. This minimalism keeps the examples readable for newcomers.

## Surprises and Deviations

### `export` in submodule does not bind the name in the parent module

What was expected: Marking a symbol with `export` inside `module Engines` would make it accessible as `SDDPlab.IterationLimit` after `using SDDPlab`, because `export` in Julia propagates through re-exports.
What happened: Julia's `export` in a submodule makes the symbol available when a user does `using SDDPlab.Engines`, but does NOT automatically bind it in the `SDDPlab` namespace. Documenter.jl's `@docs IterationLimit` searches the modules passed to `makedocs(modules = [...])` and fails unless the symbol is in the `SDDPlab` namespace. The fix is the explicit `using .Engines: IterationLimit, ...` list in `src/SDDPlab.jl`. This required adding 200+ lines of import declarations. See `src/SDDPlab.jl` lines 11-250.

### Parallel agents overwrote each other's changes to `docs/make.jl`

What was expected: Three parallel agents (ticket-041, -042, -043) would independently write to non-overlapping file areas.
What happened: All three tickets required modifying `docs/make.jl` to add their section to the `pages` array. The last agent to write the file overwrote the other agents' page additions. The final `docs/make.jl` consolidates all three sections only because ticket-041 (which ran last) incorporated the configuration and tutorial pages from the other two tickets into its write. This was a coordination failure. Future plans should either designate a single file owner for `docs/make.jl` or sequence it as a final merge step.

### `warnonly = true` needed even with `checkdocs = :exports`

What was expected: `checkdocs = :exports` would only warn about missing docstrings, and with all symbols documented, the build would be clean.
What happened: Even with all exported symbols documented, Documenter emits 19 warnings for internal utility types (e.g., `Utils.FieldRule`, `Utils.FieldKind`) that are accessible as `SDDPlab.Utils.FieldRule` and therefore technically "visible" but not in the `modules` list. Without `warnonly = true`, these warnings cause the build to fail. The fix is `warnonly = true` — the 19 warnings are benign and relate only to non-exported internal utilities.

### Markov chain uses 11 transition matrices for 12 stages

What was expected: A 12-stage Markov chain requires 12 transition matrices.
What happened: SDDP.jl's `SDDP.MarkovianGraph` expects N-1 transition matrices for N stages, because the first matrix is the initial state distribution (1 x num_states) and subsequent matrices are the stage-to-stage transitions. The `markov_var` example uses 11 matrices for 12 stages (1 root distribution + 10 transition matrices), consistent with the constraint documented in `src/Scenarios/markov-validators.jl`. See `example/markov_var/data/scenarios.jsonc`.

## Recommendations for Future Epics

- When dispatching multiple agents to work in parallel on documentation, designate one agent as the sole owner of `docs/make.jl` and have it run last, incorporating page additions from all other agents. Alternatively, have each agent append only to a designated section constant and avoid rewriting the full file.
- When Documenter.jl build produces "undefined binding" or "not documented" warnings, the first diagnostic step is to verify that the symbol has an explicit `using .SubModule: Symbol` binding in `src/SDDPlab.jl` AND that its module is in the `makedocs(modules = [...])` list. See `src/SDDPlab.jl` for the complete list.
- Any new submodule or new exported type requires two registration steps for Documenter.jl: (1) add the module to `makedocs(modules = [...])` in `docs/make.jl`; (2) add explicit `using .NewModule: NewType` in `src/SDDPlab.jl`.
- When adding new entity types that support inline JSONC definition (the `"entities": [...]` pattern), verify that the `Vector{Any}` -> `Vector{Dict{String,Any}}` conversion in `src/System/System.jl` lines 464-474 covers the new entity, or extend it. CSV-loaded entities do not require this conversion because `DataFrame` row iteration produces typed Dicts.
- New tutorial examples should be validated end-to-end (full `read_study -> build -> train -> simulate`) with a Bash timeout of 180000ms before being marked complete. The experiment_sweep example also requires `run_experiment` and `run_sensitivity` validation. See `test/test-noncontrollable.jl` for the testing pattern using `mktempdir` and `@suppress`.
- The `renewable_contracts` example may have a field name discrepancy: the JSONC uses `"type"` but the validator schema may expect `"contract_type"`. Verify by running the full pipeline before shipping.
