# ticket-043 Create Tutorial Examples for Advanced Features

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify examples run correctly and follow Julia best practices)

## Context

### Background

SDDPlab.jl now supports a wide range of features added across Epics 05-09: non-controllable generation with curtailment, energy contracts (import/export), pumping stations, stage time duration with MW-to-MWh conversion, inner load blocks (parallel and chronological), inflow non-negativity methods, multivariate stochastic processes (VAR(p)), Markov chain state transitions, out-of-sample validation, experiment runner with multi-configuration sweeps, sensitivity analysis (OAT and factorial), result aggregation and comparison, convergence analysis tools, and debug utilities. However, the existing examples in `example/` only cover basic cases (single bus with hydro+thermal, Naive or AR inflow, simple CVaR risk measure). There are no examples demonstrating the advanced features.

### Relation to Epic

This is the third ticket in Epic 10 (Documentation & Examples). It creates new example directories and tutorial documents. It operates on the `example/` directory (new subdirectories) and `docs/src/tutorials/` (new files), which do not overlap with ticket-041 (API docs in `docs/src/api/` and source docstrings) or ticket-042 (config reference in `docs/src/configuration/`). All three tickets can be executed in parallel.

### Current State

- `example/` contains 4 basic examples:
  - `1dtoy/` -- simplest case: 1 bus, 1 hydro, 1 thermal, Naive inflow, 128 iterations, CVaR
  - `1dsin/` -- 1 bus, sinusoidal inflow, Naive process
  - `1dsin_ar/` -- 1 bus, AR(1) autoregressive inflow
  - `4ree/` -- 4 buses with lines, 4 hydros, 4 thermals, inter-bus exchange
- All examples use only: buses, lines, hydros, thermals (no non-controllable, no energy contracts, no pumping stations)
- No examples use: load blocks, Markov chains, VAR processes, validation, debug, experiments, sensitivity, non-default stopping rules, non-default duality handlers, scaling, threaded parallelism
- Each example has: `main.jsonc`, `data/` directory with component JSONC and CSV files

## Specification

### Requirements

Create 5 new example directories in `example/` and corresponding tutorial documents in `docs/src/tutorials/`. Each example must be a self-contained study that can be run with the standard pipeline (`read_study` -> `build` -> `train` -> `simulate`). Each tutorial document explains what the example demonstrates and how to run it.

**Example 1: `example/renewable_contracts/`** -- Non-controllable generation and energy contracts

- System: 2 buses, 1 hydro, 1 thermal, 1 non-controllable (wind/solar), 1 import contract, 1 export contract, 1 line
- Scenarios: Naive inflow, deterministic load, 12 stages
- Engine: IterationLimit(50), Expectation risk measure, Serial, HiGHS
- Demonstrates: `noncontrollables` and `energycontracts` sections in `system.jsonc`, curtailment cost modeling, import/export contract price arbitrage
- Tutorial doc: `docs/src/tutorials/renewable_contracts.md`

**Example 2: `example/pumped_storage/`** -- Pumping stations

- System: 1 bus, 2 hydros (upper and lower reservoir), 1 thermal, 1 pumping station connecting lower to upper
- Scenarios: Naive inflow, deterministic load, 12 stages
- Engine: IterationLimit(50), CVaR(alpha=0.5, lambda=0.5), Serial, HiGHS
- Demonstrates: `pumpingstations` section in `system.jsonc`, bidirectional water flow, pump power consumption
- Tutorial doc: `docs/src/tutorials/pumped_storage.md`

**Example 3: `example/load_blocks/`** -- Inner load blocks with parallel mode

- System: 1 bus, 1 hydro, 2 thermals (base and peak), Naive inflow
- Scenarios: 3 load blocks (peak 4h, shoulder 8h, off-peak 12h), deterministic block-specific load, 12 stages
- Engine: IterationLimit(50), Expectation, Serial, HiGHS
- Demonstrates: `blocks` configuration in `scenarios.jsonc`, block-specific load data format, how duration weights affect dispatch
- Tutorial doc: `docs/src/tutorials/load_blocks.md`

**Example 4: `example/markov_var/`** -- Markov chains with VAR stochastic process

- System: 1 bus, 2 hydros (in cascade), 1 thermal, Naive or VAR inflow with 2 Markov states (wet/dry)
- Scenarios: 2-state Markov chain with transition matrices, per-state stochastic processes, 12 stages
- Engine: IterationLimit(80), CVaR(alpha=0.2, lambda=0.9), Serial, HiGHS, with validation (num_simulations=100, seed=123, branchings=5)
- Demonstrates: `markov_chain` section in `scenarios.jsonc`, per-state `inflow_scenarios.jsonc`, out-of-sample validation configuration
- Tutorial doc: `docs/src/tutorials/markov_var.md`

**Example 5: `example/experiment_sweep/`** -- Experiment runner and sensitivity analysis

- Base study: reuse `1dtoy` as the base (copy or reference)
- Experiment config: `experiment.jsonc` with 3 configurations varying risk measure (Expectation, CVaR alpha=0.2, CVaR alpha=0.5)
- Sensitivity config: `sensitivity.jsonc` with OAT sweep over `policy.convergence.max_iterations` values [32, 64, 128]
- Demonstrates: `experiment.jsonc` format, `sensitivity.jsonc` format, how to run experiments and sensitivity analysis, result comparison
- Tutorial doc: `docs/src/tutorials/experiment_sweep.md`

Each tutorial document (`docs/src/tutorials/*.md`) must contain:

- **Overview**: What advanced feature(s) this example demonstrates and why they matter
- **Study Description**: A brief description of the power system and scenario setup
- **Configuration Walkthrough**: Annotated excerpts from the JSONC config files highlighting the key configuration sections
- **Running the Example**: Exact Julia commands to run the example (using `SDDPlab.read_study`, `build`, `train`, `simulate`)
- **Expected Output**: Description of what output files are produced and what to look for in the results
- **Variations**: Suggestions for how the user can modify the example to explore further (e.g., "try changing the risk measure to WorstCase" or "add a third Markov state")

Update `docs/make.jl` to include a "Tutorials" section in the page tree with all 5 tutorial pages.

### Inputs/Props

- Existing examples in `example/` (for reference and reuse of data patterns)
- Feature code from Epics 05-09

### Outputs/Behavior

- 5 new directories in `example/`, each with `main.jsonc` and `data/` subdirectory containing all necessary JSONC and CSV files
- 5 new tutorial documents in `docs/src/tutorials/`
- Each example runs successfully with `SDDPlab.read_study` -> `build` -> `train` -> `simulate` using HiGHS solver
- `docs/make.jl` updated with the tutorials section

### Error Handling

- Keep iteration counts LOW (50-80) so examples run in seconds, not minutes
- Keep `num_simulated_series` LOW (10-50) for fast simulation
- If a feature combination causes solver issues, simplify the system while still demonstrating the feature

## Acceptance Criteria

- [ ] Given `example/renewable_contracts/`, when running `study = SDDPlab.read_study("example/renewable_contracts")`, then the study loads without errors and contains `NonControllables` and `EnergyContracts` entities
- [ ] Given `example/pumped_storage/`, when running through the full pipeline, then the output contains `PUMPED_FLOW` and `PUMP_POWER` variables with non-trivial values
- [ ] Given `example/load_blocks/`, when running through the full pipeline, then the output contains per-block dispatch results with different generation levels across blocks
- [ ] Given `example/markov_var/`, when running through the full pipeline including validation, then out-of-sample validation completes and produces statistics
- [ ] Given `example/experiment_sweep/`, when running `SDDPlab.run_experiment("example/experiment_sweep/experiment.jsonc")`, then 3 configuration subdirectories are created with results
- [ ] Given `example/experiment_sweep/`, when running `SDDPlab.run_sensitivity("example/experiment_sweep/sensitivity.jsonc")`, then sensitivity results are produced with a summary CSV
- [ ] Given each tutorial document in `docs/src/tutorials/`, when reading it, then the Julia commands shown actually work when copy-pasted into a REPL (after adjusting the path)
- [ ] Given all 5 new examples, when running each through the pipeline, then all complete in under 60 seconds on a single thread with HiGHS

## Implementation Guide

### Suggested Approach

1. **Start with Example 1 (renewable_contracts)**: This is the simplest new example -- it adds only `noncontrollables` and `energycontracts` sections to an otherwise standard system.
   - Copy `example/1dtoy/` as a starting point
   - Add a second bus and a line
   - Add `noncontrollables` section to `system.jsonc` with a `noncontrollables.csv`
   - Add `energycontracts` section to `system.jsonc` with an `energycontracts.csv`
   - Use reasonable values: wind at 50 MW max with 5.0 curtailment cost, import contract at 80 $/MWh, export at 30 $/MWh
   - Test: `read_study` -> `build` -> `train` -> `simulate`

2. **Example 2 (pumped_storage)**: Create a 2-reservoir system with a pumping station.
   - Upper reservoir (id=1): large storage, low inflow
   - Lower reservoir (id=2): small storage, high inflow, downstream_id=0
   - Pumping station: source=2 (lower), destination=1 (upper), consumption_mw_per_m3s=0.5
   - The pump should be economically attractive: cheap pumping during off-peak, generation during peak

3. **Example 3 (load_blocks)**: Add blocks to a simple system.
   - 3 blocks: "peak" (4h), "shoulder" (8h), "off-peak" (12h) = 24h total
   - Peak load: 200 MW, Shoulder: 150 MW, Off-peak: 80 MW
   - Two thermals: base (cost=10, max=100 MW) and peak (cost=50, max=150 MW)
   - Load CSV must use `BlockDeterministicLoad` format with per-block columns

4. **Example 4 (markov_var)**: Create a Markov chain example.
   - 2 Markov states: wet (state 1) and dry (state 2)
   - Transition matrix: [[0.7, 0.3], [0.4, 0.6]] for all stages
   - Per-state inflow scenarios: wet state has higher inflows, dry state has lower
   - Add validation config with num_simulations=50, seed=123, branchings=5

5. **Example 5 (experiment_sweep)**: Create experiment and sensitivity configs.
   - `experiment.jsonc` references `../1dtoy` as base study
   - 3 configs: `"expectation"` (Expectation), `"cvar_02"` (CVaR alpha=0.2), `"cvar_05"` (CVaR alpha=0.5)
   - `sensitivity.jsonc` references `../1dtoy` as base study
   - 1 parameter: `"path": "policy.convergence.max_iterations"`, values: [32, 64, 128]
   - Set `max_iterations` in stopping_criteria to match for consistency

6. **Write tutorial documents** for each example after verifying it runs.

7. **Update `docs/make.jl`** to include the tutorials section.

### Key Files to Create

**Example directories (each with main.jsonc + data/ subdirectory):**

- `example/renewable_contracts/main.jsonc`
- `example/renewable_contracts/data/` (system.jsonc, scenarios.jsonc, constraints.jsonc, buses.csv, lines.csv, hydros.csv, thermals.csv, noncontrollables.csv, energycontracts.csv, graph.jsonc, inflow_scenarios.jsonc, load.csv)
- `example/pumped_storage/main.jsonc`
- `example/pumped_storage/data/` (system.jsonc, scenarios.jsonc, constraints.jsonc, buses.csv, hydros.csv, thermals.csv, pumpingstations.csv, graph.jsonc, inflow_scenarios.jsonc, load.csv)
- `example/load_blocks/main.jsonc`
- `example/load_blocks/data/` (system.jsonc, scenarios.jsonc, constraints.jsonc, buses.csv, hydros.csv, thermals.csv, graph.jsonc, inflow_scenarios.jsonc, load.csv)
- `example/markov_var/main.jsonc`
- `example/markov_var/data/` (system.jsonc, scenarios.jsonc, constraints.jsonc, buses.csv, hydros.csv, thermals.csv, graph.jsonc, inflow_scenarios.jsonc, load.csv, markov_chain.jsonc or inline)
- `example/experiment_sweep/experiment.jsonc`
- `example/experiment_sweep/sensitivity.jsonc`

**Tutorial documents:**

- `docs/src/tutorials/renewable_contracts.md`
- `docs/src/tutorials/pumped_storage.md`
- `docs/src/tutorials/load_blocks.md`
- `docs/src/tutorials/markov_var.md`
- `docs/src/tutorials/experiment_sweep.md`

### Key Files to Modify

- `docs/make.jl` -- add tutorials section to pages

### Key Files to Read (reference for config formats)

- `example/1dtoy/` -- base example to copy patterns from
- `src/System/noncontrollable-validators.jl` -- NonControllable CSV column names
- `src/System/energycontract-validators.jl` -- EnergyContract CSV column names
- `src/System/pumpingstation-validators.jl` -- PumpingStation CSV column names
- `src/Scenarios/blocks.jl` -- Block config format
- `src/Scenarios/markov-validators.jl` -- Markov chain config format
- `src/Scenarios/load-validators.jl` + `load.jl` -- Load format for block mode
- `src/Experiments/config.jl` -- Experiment config parsing
- `src/Experiments/sensitivity.jl` -- Sensitivity config parsing

### Patterns to Follow

- Follow the same directory structure as existing examples: `main.jsonc` at root, `data/` subdirectory with all component files
- Use the same CSV format patterns as existing examples (header row with column names, comma-separated)
- Keep iteration counts to 50-80 max for fast execution
- Keep `num_simulated_series` to 10-50 for fast simulation
- Use HiGHS solver (not GLPK) as it is thread-safe and the default
- Use `"kind"` / `"params"` pattern for all polymorphic config sections

### Pitfalls to Avoid

- Do NOT create examples that take more than 60 seconds to run -- keep systems small (1-4 buses, 1-4 hydros)
- Do NOT use GLPK in any example -- always use HiGHS
- The `BlockDeterministicLoad` kind for load requires specific column format with block names -- read `src/Scenarios/load-validators.jl` to get the exact format
- Markov chain `transition_matrices` must be properly formatted: first matrix is `[1 x num_states]` (root distribution), subsequent matrices are `[num_states x num_states]` (row-stochastic) -- verify with `src/Scenarios/markov-validators.jl`
- The experiment runner calls `read_study` from the base_study_path, so relative paths in the experiment config must resolve correctly
- For the sensitivity example, the `path` field uses dot notation (e.g., `"policy.convergence.max_iterations"`) -- this navigates into the engine params dict
- Lines CSV needs `exchange_penalty` column (default 0.01 if using `default_values`)
- Pumping station requires both `source_hydro_id` and `destination_hydro_id` to reference valid hydro IDs
- Energy contract `contract_type` must be exactly `"import"` or `"export"` (lowercase)
- The `constraints.jsonc` file can be empty `{}` or just `{}` -- it is required by the file reference but has no active content

## Testing Requirements

### Unit Tests

- No new unit tests required

### Integration Tests

- For each of the 5 new examples, run the full pipeline and verify it completes without error:
  ```julia
  study = SDDPlab.read_study("example/<name>")
  model = SDDPlab.build(study)
  artifact = SDDPlab.train(study, model)
  sim = SDDPlab.simulate(study, model)
  ```
- For `experiment_sweep`, also test:
  ```julia
  results = SDDPlab.run_experiment("example/experiment_sweep/experiment.jsonc")
  sens = SDDPlab.run_sensitivity("example/experiment_sweep/sensitivity.jsonc")
  ```
- Use Bash timeout of 180000ms for each test run
- Use `@suppress` from Suppressor.jl to silence SDDP output

### E2E Tests

- Not applicable (examples are self-verifying by running without error)

## Dependencies

- **Blocked By**: None (Epic 09 complete; all source code is finalized)
- **Blocks**: None (ticket-041 and ticket-042 are independent)

## Effort Estimate

**Points**: 5
**Confidence**: Medium (creating 5 working example cases with valid data requires careful attention to CSV formats and config schemas; the existing examples provide a strong template but the advanced features add complexity)
