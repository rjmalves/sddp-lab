# ticket-042 Write Configuration Format Reference

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify config examples match actual JSONC schema)

## Context

### Background

SDDPlab.jl is entirely configuration-driven: users define their studies through a hierarchy of JSONC files (`main.jsonc`, `system.jsonc`, `scenarios.jsonc`, `constraints.jsonc`). The configuration format has grown substantially across 9 epics, adding engine options (risk measures, stopping rules, sampling schemes, duality handlers, forward pass strategies, cut types, scaling, logging, diagnostics, solver, validation, debug, inflow non-negativity), system elements (non-controllable generation, energy contracts, pumping stations), scenario features (load blocks, Markov chains, multivariate stochastic processes, stage time duration), and experiment orchestration files (`experiment.jsonc`, `sensitivity.jsonc`). There is currently no single reference document that covers the complete configuration format.

### Relation to Epic

This is the second ticket in Epic 10 (Documentation & Examples). It creates a standalone configuration reference document. It operates on different files from ticket-041 (API docs) and ticket-043 (tutorials), so all three can be executed in parallel.

### Current State

- The configuration format is defined implicitly by the validator code in:
  - `src/Engines/sddp/input-validators.jl` (FieldRule schemas for all engine options)
  - `src/Engines/sddp/input.jl` (constructors with default values and \__build_\* functions)
  - `src/Engines/input-validators.jl` (top-level engine validation)
  - `src/Engines/input.jl` (engine construction)
  - `src/Scenarios/scenariosdata-validators.jl`, `src/Scenarios/blocks.jl`, `src/Scenarios/markov-validators.jl`, `src/Scenarios/markov.jl` (scenario validation)
  - `src/System/systemdata-validators.jl`, `src/System/*-validators.jl` (system validation)
  - `src/Experiments/config.jl`, `src/Experiments/sensitivity.jl` (experiment configs)
- Existing examples in `example/` demonstrate basic configs but do NOT cover advanced features (load blocks, Markov chains, energy contracts, pumping stations, non-controllable generation, validation, debug, logging, sensitivity, experiments)
- The only existing documentation (`docs/src/man/getting_started.md`) shows the old file structure with `tasks.jsonc`/`algorithm.jsonc` which no longer exists

## Specification

### Requirements

1. **Create `docs/src/configuration/` directory** with the following prose reference documents:

2. **`docs/src/configuration/overview.md`** -- Configuration overview:
   - Explain the JSONC file hierarchy: `main.jsonc` -> `data/` directory -> component files
   - Explain the `{"kind": "TypeName", "params": {...}}` pattern used throughout
   - Explain the `"file": "path.csv"` pattern for external entity data
   - Explain default values and optional keys
   - Provide a minimal complete example `main.jsonc`

3. **`docs/src/configuration/system.md`** -- System configuration reference:
   - `system.jsonc` top-level structure with all entity sections
   - **Buses**: CSV columns (`id`, `name`, `deficit_cost`), `default_values` support
   - **Lines**: CSV columns (`id`, `name`, `source_bus_id`, `target_bus_id`, `capacity`, `exchange_penalty`), `default_values` support
   - **Hydros**: CSV columns (`id`, `downstream_id`, `name`, `bus_id`, `productivity`, `initial_storage`, `min_storage`, `max_storage`, `min_generation`, `max_generation`, `spillage_penalty`), `default_values` support, downstream topology explanation
   - **Thermals**: CSV columns (`id`, `name`, `bus_id`, `min_generation`, `max_generation`, `cost`)
   - **NonControllables**: CSV columns (`id`, `name`, `bus_id`, `max_generation`, `curtailment_cost`), explain curtailment modeling
   - **EnergyContracts**: CSV columns (`id`, `name`, `bus_id`, `contract_type`, `price_per_mwh`, `min_mw`, `max_mw`), explain `"import"`/`"export"` types
   - **PumpingStations**: CSV columns (`id`, `name`, `bus_id`, `source_hydro_id`, `destination_hydro_id`, `consumption_mw_per_m3s`, `min_m3s`, `max_m3s`), explain bidirectional water pumping
   - For each entity section, provide an annotated JSONC example and an example CSV

4. **`docs/src/configuration/scenarios.md`** -- Scenarios configuration reference:
   - `scenarios.jsonc` top-level structure: `seed`, `initial_season`, `branchings`, `graph`, `inflow`, `load`
   - **Graph**: explain the `graph.jsonc` format (nodes with stages, edges with probabilities and discount rates), how it defines the scenario tree
   - **Inflow / Stochastic Processes**:
     - `Naive`: flat scenarios per hydro per stage, `inflow_scenarios.jsonc` format
     - `AutoRegressive` (PAR(p)): parameters (`phi`, `sigma`, `mu`, `lag`), how lag order works
     - `VectorAutoRegressive` (VAR(p)): multivariate parameters (coefficient matrices, scales, copulas), flat indexing convention
     - Per-state stochastic processes for Markov mode
   - **Load**: `DeterministicLoad` kind with `load.csv` format; `BlockDeterministicLoad` with block-specific load columns
   - **Blocks** (optional): `blocks` key with `mode` (`"parallel"` or `"chronological"`), `definitions` array (`name`, `duration_hours`)
   - **Markov Chain** (optional): `markov_chain` key with `transition_matrices` array format
   - Annotated JSONC examples for each subsection

5. **`docs/src/configuration/engine.md`** -- Engine configuration reference:
   - `engine` section in `main.jsonc`: `kind` (always `"SDDPEngine"`), `params` dict
   - **Policy configuration** (`policy` subsection):
     - `convergence`: `min_iterations`, `max_iterations`, `stopping_criteria`
       - All stopping criteria kinds: `IterationLimit`, `TimeLimit`, `LowerBoundStability`, `Statistical`, `SimulationStopping`, `FirstStageStopping`, `StoppingChain` (with nested rules)
       - Show both single-criteria (Dict) and multi-criteria (Array) syntax
     - `risk_measure`: all kinds with their params -- `Expectation`, `WorstCase`, `AVaR` (alpha), `CVaR` (alpha, lambda), `Entropic` (theta), `WassersteinRM` (alpha), `ModifiedChiSquared` (radius, minimum_std), `ConvexCombination` (measures array with weight + risk_measure)
     - `parallel_scheme`: `Serial`, `Threaded`, `Asynchronous`
     - `sampling_scheme` (optional, default `DefaultSampling`): `InSampleMC` (max_depth, terminate_on_dummy_leaf), `PSRSampling` (num_samples)
     - `duality_handler` (optional, default `DefaultDuality`): `ContinuousConicDualityHandler`, `StrengthenedConicDualityHandler`, `LagrangianDualityHandler`, `BanditDualityHandler` (handlers array)
     - `forward_pass` (optional, default `DefaultForwardPassStrategy`): `RevisitingForwardPassStrategy` (period), `RiskAdjustedForwardPassStrategy`, `RegularizedForwardPassStrategy` (rho)
     - `cut_type` (optional, default `SingleCut`): `MultiCut`
     - `scaling` (optional, default `NoScaling`): `AutoScaling`
     - `logging` (optional): `log_file`, `log_frequency`, `log_every_iteration`, `print_level`
   - **Simulation configuration** (`simulation` subsection): `num_simulated_series`, `parallel_scheme`, `sampling_scheme`
   - **Solver** (`solver` subsection, optional, default HiGHS): `name`, `attributes`
   - **Diagnostics** (`diagnostics` subsection, optional): `run_numerical_report`, `warn_threshold`, `halt_threshold`
   - **Inflow non-negativity** (`modeling.inflow_non_negativity`, optional, default `InflowNone`): `InflowPenalty` (penalty_cost), `InflowTruncation`, `InflowTruncationWithPenalty` (penalty_cost)
   - **Validation** (`validation` subsection, optional): `num_simulations`, `seed`, `branchings`, `parallel_scheme`
   - **Debug** (`debug` subsection, optional): `write_subproblems`, `subproblem_nodes`, `subproblem_format` (mof/lp/mps), `deterministic_equivalent`, `det_equiv_time_limit`
   - For each subsection, provide an annotated JSONC example showing all available options

6. **`docs/src/configuration/experiments.md`** -- Experiment orchestration reference:
   - `experiment.jsonc` format: `base_study`, `output_dir`, `configurations` (name -> engine params overrides), `overwrite`
   - `sensitivity.jsonc` format: `base_study`, `output_dir`, `mode` (oat/factorial), `base_overrides`, `parameters` (label, path, values), `overwrite`
   - Annotated examples for both file types

7. **Update `docs/make.jl`** to include the configuration reference pages in the page tree (if ticket-041 has not already done so; if ticket-041 runs first, add to the existing page tree).

### Inputs/Props

- Source code validators and input constructors (listed in Current State)
- Existing example configs in `example/`

### Outputs/Behavior

- A complete, browsable set of configuration reference documents in `docs/src/configuration/`
- Each config key is documented with: type, valid values, default (if optional), and an example
- The reference is written as human-authored prose with annotated JSONC examples (NOT auto-generated from code)

### Error Handling

- If a config key's behavior is unclear from the code, document the observable behavior and add a NOTE callout
- If a default value differs between documentation and code, trust the code

## Acceptance Criteria

- [ ] Given `docs/src/configuration/overview.md`, when reading it, then a new user can understand the JSONC file hierarchy, the `kind`/`params` pattern, and the `file` reference pattern
- [ ] Given `docs/src/configuration/system.md`, when reading it, then every system entity type (`buses`, `lines`, `hydros`, `thermals`, `noncontrollables`, `energycontracts`, `pumpingstations`) is documented with all CSV columns, types, and an annotated example
- [ ] Given `docs/src/configuration/scenarios.md`, when reading it, then all scenario config keys are documented including `graph`, `inflow` (Naive, AutoRegressive, VectorAutoRegressive), `load`, `blocks`, and `markov_chain`
- [ ] Given `docs/src/configuration/engine.md`, when reading it, then every engine config key is documented: all stopping criteria kinds, all risk measure kinds, all parallel schemes, all sampling schemes, all duality handlers, all forward pass strategies, both cut types, both scaling modes, solver config, diagnostics, logging, debug, validation, and inflow non-negativity
- [ ] Given `docs/src/configuration/experiments.md`, when reading it, then both `experiment.jsonc` and `sensitivity.jsonc` formats are fully documented with annotated examples
- [ ] Given any config key documented in the reference, when checking the corresponding validator code, then the documented type, constraints, and default value match the code
- [ ] Given the configuration reference pages, when building the docs site with `julia --project=docs/ docs/make.jl`, then all config pages render correctly without broken links or formatting errors

## Implementation Guide

### Suggested Approach

1. **Start with `overview.md`**: Explain the file hierarchy pattern, the `kind`/`params` resolution, and the `file` reference for CSV entities. Use `example/1dtoy/` as the running example.

2. **Write `system.md`**: For each entity type, read the corresponding `-validators.jl` file to extract the exact CSV column names and types, and the `default_values` support. Read the struct definition in the entity file for field documentation.

3. **Write `scenarios.md`**: Read `src/Scenarios/scenariosdata-validators.jl` and `scenariosdata.jl` for the top-level keys. Read `blocks.jl` for block config. Read `markov-validators.jl` and `markov.jl` for Markov chain format. Read `src/StochasticProcess/*-validators.jl` for stochastic process params.

4. **Write `engine.md`**: This is the largest section. Work through `src/Engines/sddp/input-validators.jl` schema by schema, extracting each key's type and constraints. For each `__build_*` function in `src/Engines/sddp/input.jl`, note the default value when the key is absent. Document each kind with its params using the `kind`/`params` JSONC pattern.

5. **Write `experiments.md`**: Read `src/Experiments/config.jl` for experiment config parsing and `src/Experiments/sensitivity.jl` for sensitivity config parsing.

6. **Update `docs/make.jl`** to add the configuration pages.

### Key Files to Create

- `docs/src/configuration/overview.md` -- NEW
- `docs/src/configuration/system.md` -- NEW
- `docs/src/configuration/scenarios.md` -- NEW
- `docs/src/configuration/engine.md` -- NEW
- `docs/src/configuration/experiments.md` -- NEW

### Key Files to Modify

- `docs/make.jl` -- add configuration reference section to pages

### Key Files to Read (source of truth for config schemas)

- `src/Engines/sddp/input-validators.jl` -- all FieldRule schemas with types and constraints
- `src/Engines/sddp/input.jl` -- default values in `__build_*` functions, constructor logic
- `src/Engines/input-validators.jl` -- top-level engine keys
- `src/Engines/input.jl` -- engine construction, `__build_engine!`
- `src/Scenarios/scenariosdata-validators.jl` -- scenarios validation
- `src/Scenarios/blocks.jl` -- block config parsing
- `src/Scenarios/markov-validators.jl` + `markov.jl` -- Markov chain config
- `src/System/*-validators.jl` -- system entity CSV column validation
- `src/Experiments/config.jl` -- experiment config parsing
- `src/Experiments/sensitivity.jl` -- sensitivity config parsing
- `example/1dtoy/` -- reference example configs

### Patterns to Follow

- Use Documenter.jl `!!! note` and `!!! warning` admonition syntax for callouts
- Use JSONC code blocks with annotations (comments inside the JSON)
- For each config section, follow the pattern: brief description -> key table (Name | Type | Required | Default | Description) -> annotated example
- Use consistent terminology: "kind" for the type discriminator, "params" for the parameters dict

### Pitfalls to Avoid

- Do NOT auto-generate the reference from code -- write human-readable prose with domain context
- Do NOT create a JSON Schema file (that is a separate feature if ever needed)
- Do NOT duplicate the API reference (ticket-041) -- link to it for type details using `[`SDDPEngine`](@ref)` syntax where appropriate
- The `constraints.jsonc` file is currently empty (used as a placeholder) -- document it as "reserved for future constraints" with a note
- The `"kind"` resolution is case-sensitive and uses exact Julia type names -- document this clearly
- Several engine options are deeply nested (`modeling.inflow_non_negativity` is under a `modeling` key, not directly under engine params) -- follow the code exactly

## Testing Requirements

### Unit Tests

- No new unit tests required (this is a documentation-only ticket)

### Integration Tests

- Verify the documentation builds successfully: `julia --project=docs/ docs/make.jl`
- Verify all config pages render without broken links

### E2E Tests

- Manually verify that every JSONC example in the documentation is syntactically valid JSONC

## Dependencies

- **Blocked By**: None (Epic 09 complete; all source code is finalized)
- **Blocks**: None (ticket-041 and ticket-043 are independent)

## Effort Estimate

**Points**: 4
**Confidence**: Medium (the scope is well-defined but writing comprehensive config documentation for 30+ option types with annotated examples is substantial; all information is extractable from source code)
