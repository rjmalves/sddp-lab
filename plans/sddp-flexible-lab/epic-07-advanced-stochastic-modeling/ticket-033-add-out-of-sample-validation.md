# ticket-033 Add Out-of-Sample Validation Framework

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify statistical computation performance)

## Context

### Background

After training an SDDP policy, practitioners need to assess its quality by simulating on scenarios that were not used during training. Currently, SDDPlab only supports in-sample simulation: the same SAA scenarios used for cut generation are used for policy evaluation. This conflates training fit with generalization quality.

SDDP.jl provides `OutOfSampleMonteCarlo` as a sampling scheme that takes a user-defined function returning new noise terms per node. This allows simulation on independently generated scenarios. Combined with statistical metrics (mean cost, confidence intervals, worst-case cost), this gives practitioners a rigorous assessment of policy robustness.

This ticket adds an out-of-sample validation task that: (a) generates independent scenario sets from the same stochastic model with a different seed, (b) simulates the trained policy on those scenarios via `SDDP.OutOfSampleMonteCarlo`, and (c) computes and reports statistical metrics.

### Relation to Epic

This is the third and final ticket in Epic 07. It builds on the stochastic process infrastructure from tickets 031-032. The validation framework works with any stochastic process type (Naive, AutoRegressive, VectorAutoRegressive) and with both linear and Markov policy graphs.

### Current State

- `src/Engines/sddp/simulate.jl`: `Lab.simulate(model, definition)` calls `__simulate_model` which uses `SDDP.simulate` with a sampling scheme from the simulation task definition. Currently only `InSampleMonteCarlo`, `PSRSampling`, and `DefaultSampling` are supported.
- `src/Engines/Engines.jl`: `SDDPSimulationTaskDefinition` has 3 fields: `num_simulated_series`, `parallel_scheme`, `sampling_scheme`. The simulation returns `SDDPSimulationTaskArtifact`.
- `src/Engines/sddp/save_simulation.jl`: `Lab.save_simulation` writes DataFrames to CSV/Parquet with variable-per-entity output.
- `src/Lab/tasks.jl`: Defines abstract `simulate` interface.
- `src/study.jl`: `simulate(study, model)` calls through the engine.
- SDDP.jl: `OutOfSampleMonteCarlo(f, graph; use_insample_transition, max_depth, ...)` takes a function `f(node)` that returns `(children_noise, stagewise_noise)` tuples of `SDDP.Noise` vectors. With `use_insample_transition=true`, `f(node)` only returns stagewise noise.
- Epic-02 learnings: `OutOfSampleMonteCarlo` was deferred because it "requires a separate scenario tree specification."

## Specification

### Requirements

1. **New `OutOfSampleValidation` task definition type**: Holds the number of out-of-sample simulations, a separate seed for scenario generation, the number of branchings (scenarios per stage), and parallel scheme. This is separate from the existing `SDDPSimulationTaskDefinition`.
2. **Out-of-sample scenario generation**: Generate a fresh SAA from the same stochastic process using a different seed. This SAA is passed to `SDDP.OutOfSampleMonteCarlo` with `use_insample_transition=true` (keep the in-sample graph transitions, only replace the noise terms).
3. **Validation simulation**: Simulate the trained policy on out-of-sample scenarios using `SDDP.simulate` with `OutOfSampleMonteCarlo` as the sampling scheme.
4. **Statistical metrics computation**: From the out-of-sample simulation results, compute:
   - Mean total cost across simulations
   - Standard deviation of total cost
   - 95% confidence interval for mean cost (using t-distribution for small samples, normal for large)
   - Percentile costs: 5th, 50th (median), 95th
   - Maximum cost (worst case)
5. **Metrics output**: Write a summary statistics file alongside the simulation output.
6. **JSONC configuration**: The validation task is configured via an optional `"validation"` key in the engine JSONC, under a new `"out_of_sample"` sub-key within the `"simulation"` section or as a separate top-level engine section.
7. **Public API**: Add `validate(study, model)` to the study-level API, returning a validation artifact.
8. **Backward compatibility**: When no `"validation"` key is present, the system behaves identically to before.

### Inputs/Props

Engine JSONC configuration:

```jsonc
{
  "kind": "SDDPEngine",
  "params": {
    "policy": {
      /* ... */
    },
    "simulation": {
      /* ... existing simulation config ... */
    },
    "validation": {
      "num_simulations": 1000,
      "seed": 99999,
      "branchings": 100,
      "parallel_scheme": { "kind": "Serial", "params": {} },
    },
    "diagnostics": {
      /* ... */
    },
    "solver": {
      /* ... */
    },
  },
}
```

When `"validation"` is absent, no validation task is created.

### Outputs/Behavior

- `validate(study, model)` returns an `SDDPValidationTaskArtifact` containing the out-of-sample simulation results and computed statistics.
- `save_validation(artifact, path, format, files)` writes:
  1. The same per-variable output files as regular simulation (prefixed with `validation_` or in a `validation/` subdirectory)
  2. A `validation_statistics.csv` / `validation_statistics.parquet` file with summary metrics
- The statistics file contains one row per metric: `metric_name`, `value`.

### Error Handling

- Invalid `num_simulations` (not positive): accumulate `AssertionError`
- Invalid `seed` (not positive integer): accumulate `AssertionError`
- `validate` called without a trained model: SDDP.jl will error at `SDDP.simulate` -- catch and re-throw with descriptive message
- If `OutOfSampleMonteCarlo` construction fails (e.g., dimension mismatch): catch, log, and re-throw with context

## Acceptance Criteria

- [ ] Given an engine JSONC without `"validation"` key, when the engine is constructed, then no validation config is created and the engine has 5 fields (unchanged).
- [ ] Given an engine JSONC with `"validation"` key, when the engine is constructed, then the `SDDPEngine` has 6 fields including an `OutOfSampleValidation` definition.
- [ ] Given a trained SDDP model and a validation config with `num_simulations=100`, `seed=99999`, `branchings=50`, when `validate(study, model)` is called, then SDDP.simulate runs with `OutOfSampleMonteCarlo` using independently generated scenarios.
- [ ] Given the out-of-sample simulation results, when statistics are computed, then mean cost, std, 95% CI, 5th/50th/95th percentiles, and max cost are correct (verified against hand computation on small sample).
- [ ] Given a validation artifact, when `save_validation` is called, then simulation output files and a `validation_statistics` file are written.
- [ ] Given a `Naive` stochastic process with seed 12345 (training) and validation seed 99999, when out-of-sample scenarios are generated, then the scenarios differ from the training SAA (not statistically identical).
- [ ] Given an `AutoRegressive` or `VectorAutoRegressive` process, when validation is run, then the out-of-sample scenarios correctly use the noise model with the validation seed.
- [ ] Given a Markov policy graph (from ticket-032), when validation is run, then `OutOfSampleMonteCarlo` with `use_insample_transition=true` works correctly with tuple nodes.

## Implementation Guide

### Suggested Approach

1. **Add types to `src/Engines/Engines.jl`**:

   ```julia
   struct OutOfSampleValidation
       num_simulations::Integer
       seed::Integer
       branchings::Integer
       parallel_scheme::ParallelScheme
   end

   struct SDDPValidationTaskArtifact
       simulations::Vector{Vector{Dict{Symbol,Any}}}
       scaling::ScalingConfig
       statistics::Dict{String,Float64}
   end
   ```

   Add `OutOfSampleValidation` as an optional 6th field on `SDDPEngine`:

   ```julia
   struct SDDPEngine <: Engine
       policy::SDDPPolicyTaskDefinition
       simulation::SDDPSimulationTaskDefinition
       diagnostics::DiagnosticsConfig
       solver::SolverConfig
       inflow_non_negativity::InflowNonNegativity
       validation::Union{OutOfSampleValidation,Nothing}
   end
   ```

   Note: This is one case where `Union{T, Nothing}` is appropriate because validation is truly optional with no meaningful "empty" default behavior (unlike entity collections which default to empty vectors). Alternatively, follow the abstract type pattern: `abstract type AbstractValidation end; struct NoValidation <: AbstractValidation end; struct OutOfSampleValidation <: AbstractValidation end`.

2. **Add constructor and builder in `src/Engines/input.jl`**:
   - `OutOfSampleValidation(d::Dict{String,Any}, e::CompositeException)`: Validate schema, construct struct.
   - `__build_validation!(d, e)`: Check `haskey(d, "validation")`. If absent, set default (Nothing or NoValidation). If present, parse the dict.

3. **Add validation schema in `src/Engines/input-validators.jl`**:
   - Schema for `OutOfSampleValidation`: `num_simulations` (positive Integer), `seed` (positive Integer), `branchings` (positive Integer), `parallel_scheme` (ParallelScheme via `__kind_factory!`).
   - Update `__build_sddp_engine_internals_from_dicts!` to call `__build_validation!`.
   - Update `__validate_sddp_engine_keys_types!` to include the validation field.

4. **Create `src/Engines/sddp/validate.jl`**: Core validation logic:

   ```julia
   function Lab.validate(model::SDDPModel, validation::OutOfSampleValidation,
                         files::Vector{InputModule})::SDDPValidationTaskArtifact
       scenarios = get_scenarios(files)
       inflow = scenarios.inflow
       # Generate out-of-sample SAA with different seed
       oos_saa = generate_saa(scenarios, num_stages, validation.seed)
       # ... apply scaling, truncation as in __generate_subproblem_builder
       # Build OutOfSampleMonteCarlo sampling scheme
       sampler = SDDP.OutOfSampleMonteCarlo(
           model.policy_graph;
           use_insample_transition = true,
       ) do node
           # node is Integer or Tuple{Int,Int}
           stage_index = _extract_stage(node)
           return [SDDP.Noise(oos_saa[stage_index][b], 1.0 / length(oos_saa[stage_index]))
                   for b in eachindex(oos_saa[stage_index])]
       end
       # Simulate
       sims = SDDP.simulate(model.policy_graph, validation.num_simulations, [...];
           sampling_scheme = sampler, ...)
       # Compute statistics
       stats = _compute_validation_statistics(sims)
       return SDDPValidationTaskArtifact(sims, model.scaling, stats)
   end
   ```

5. **Add statistics computation**:

   ```julia
   function _compute_validation_statistics(
       sims::Vector{Vector{Dict{Symbol,Any}}}
   )::Dict{String,Float64}
       total_costs = [sum(stage[TOTAL_COST] for stage in sim) for sim in sims]
       n = length(total_costs)
       mu = mean(total_costs)
       sigma = std(total_costs)
       se = sigma / sqrt(n)
       z = n >= 30 ? 1.96 : _t_quantile_95(n - 1)  # or use Distributions.jl
       return Dict(
           "mean_cost" => mu,
           "std_cost" => sigma,
           "ci_lower_95" => mu - z * se,
           "ci_upper_95" => mu + z * se,
           "p05_cost" => quantile(total_costs, 0.05),
           "p50_cost" => quantile(total_costs, 0.50),
           "p95_cost" => quantile(total_costs, 0.95),
           "max_cost" => maximum(total_costs),
           "min_cost" => minimum(total_costs),
           "num_simulations" => Float64(n),
       )
   end
   ```

6. **Add `validate` to study-level API in `src/study.jl`**:

   ```julia
   function validate(study::Study, model::Model)
       validation = get_validation_definition(study.engine)
       isnothing(validation) && error("No validation configuration in engine")
       return Lab.validate(model, validation, study.inputs.files)
   end
   ```

7. **Add `save_validation` in `src/Engines/sddp/save_simulation.jl`** (or a new `validate.jl`): Reuse `_unscale_simulations` and `__write_simulation_results` with a `validation_` prefix.

8. **Update `src/Lab/tasks.jl`**: Add abstract `validate` function signature.

9. **Update `src/Lab/Lab.jl`**: Export `validate` and `save_validation`.

### Key Files to Modify

- **Modify**: `src/Engines/Engines.jl` (add `OutOfSampleValidation`, `SDDPValidationTaskArtifact`, update `SDDPEngine`)
- **Modify**: `src/Engines/input.jl` (add constructor, builder for validation)
- **Modify**: `src/Engines/input-validators.jl` (add schema, update engine internals builder)
- **New**: `src/Engines/sddp/validate.jl` (core validation logic)
- **Modify**: `src/Engines/sddp/simulate.jl` or `save_simulation.jl` (add save_validation, reuse output logic)
- **Modify**: `src/Lab/tasks.jl` (add validate signature)
- **Modify**: `src/Lab/Lab.jl` (add exports)
- **Modify**: `src/study.jl` (add validate function)
- **New**: `test/Engines/test-validation.jl`

### Patterns to Follow

- Backward-compat via `haskey(d, "validation")` guard (same as `"modeling"` key pattern from epic-06)
- `__build_*!` pattern for engine internals (see `__build_inflow_non_negativity!` in `input.jl`)
- `generate_sampling_scheme` / `generate_parallel_scheme` for mapping SDDPlab types to SDDP.jl types
- `SDDPSimulationTaskArtifact` pattern for the validation artifact
- `SDDP.simulate` call pattern from `__simulate_model` in `simulate.jl`
- Statistics: use `Statistics.mean`, `Statistics.std`, `Statistics.quantile` from stdlib

### Pitfalls to Avoid

- **OutOfSampleMonteCarlo requires the model (policy_graph)**: The `SDDP.OutOfSampleMonteCarlo` constructor takes the policy graph as its second argument (to read the graph structure). This means the sampler must be constructed after the model is trained and the policy graph is available.
- **Node type genericity**: When Markov chain is active, nodes are `(stage, markov_state)` tuples. The `OutOfSampleMonteCarlo` callback `f(node)` receives the node as-is. Extract stage with a helper: `_extract_stage(node::Integer) = node; _extract_stage(node::Tuple) = node[1]`.
- **SAA scaling**: The out-of-sample SAA must undergo the same scaling and truncation as the training SAA (see `__generate_subproblem_builder` lines where `s_flow` divides SAA and truncation is applied for `InflowTruncation`/`InflowTruncationWithPenalty`).
- **Noise probability**: Each noise realization in `OutOfSampleMonteCarlo` needs a probability. With equal-probability branchings: `1.0 / B` where `B` is the number of branchings.
- **Total cost extraction**: SDDP.jl records `TOTAL_COST` per stage. The policy cost for one simulation is the sum across stages. Verify the key matches the custom recorder in `__simulate_model`.
- **Markov state-dependent SAA**: When Markov chain is active, the out-of-sample SAA should be per Markov state. The `OutOfSampleMonteCarlo` callback must return the correct SAA for the node's Markov state.
- **Do NOT add `using Statistics` at module level if it is not already imported**: Check current imports. `Statistics` is in Julia stdlib and may need explicit `using`.
- **Test file isolation**: Create `test/Engines/test-validation.jl`. Use `TEST_FILTER="test-validation"` with 120000ms timeout.

## Testing Requirements

### Unit Tests

Create `test/Engines/test-validation.jl`:

1. **Constructor tests**: Valid validation config constructs successfully; missing fields fail; invalid values (non-positive num_simulations, non-positive seed) fail with errors
2. **Engine construction**: `SDDPEngine` with validation key constructs with 6 fields; without key constructs with 5 fields or default NoValidation
3. **Statistics computation**: Given a known vector of total costs `[100, 200, 300, 400, 500]`, verify mean=300, std, CI, percentiles, max=500 against hand-computed values
4. **Out-of-sample SAA generation**: Given a Naive process, verify that SAA with seed 12345 differs from SAA with seed 99999

### Integration Tests

- Build a small SDDP model (2 stages, 1 hydro, Naive process), train for 5 iterations, run validation with 10 simulations. Verify that `SDDPValidationTaskArtifact` contains simulations and statistics.
- Verify `save_validation` writes output files.

### E2E Tests (if applicable)

- Full study with validation: `read_study`, `build`, `train`, `validate`, `save_validation`. Verify end-to-end pipeline completes without errors. This can be a smoke test on a minimal example case.

## Dependencies

- **Blocked By**: ticket-032 (Markov chain support must exist for the validation to handle Markov nodes in `OutOfSampleMonteCarlo`)
- **Blocks**: None

## Effort Estimate

**Points**: 4
**Confidence**: Medium (the core mechanism uses SDDP.jl's existing OutOfSampleMonteCarlo API, but integrating it cleanly with the SDDPlab task pipeline and handling Markov nodes adds complexity)
