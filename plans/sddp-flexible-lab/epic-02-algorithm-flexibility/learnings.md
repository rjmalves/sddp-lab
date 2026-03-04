# Epic 02 Learnings: Algorithm Flexibility

**Date**: 2026-02-17
**Scope**: Tickets 010-016
**Net change**: +1931 / -146 lines across 17 files

---

## Patterns Established

### 1. Parameterless Option Type Pattern

Types with no configuration parameters (Serial, Expectation, DefaultSampling, ContinuousConicDualityHandler, DefaultForwardPassStrategy, SingleCut, etc.) follow a minimal constructor pattern: the `TypeName(::Dict{String,Any}, ::CompositeException)` method ignores both arguments and returns the singleton-like instance. No schema constant is needed and no validation is performed. This pattern recurred in 10+ types across Epic 02: `DefaultSampling`, `DefaultDuality`, `ContinuousConicDualityHandler`, `StrengthenedConicDualityHandler`, `LagrangianDualityHandler`, `DefaultForwardPassStrategy`, `RiskAdjustedForwardPassStrategy`, `SingleCut`, `MultiCut`. Canonical example: `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 119-121 (`DefaultSampling` constructor).

### 2. Nested Composite Type Pattern (ConvexCombination, StoppingChain, BanditDualityHandler)

Three types contain vectors of their own abstract parent type: `ConvexCombination` holds `Vector{Tuple{Real,RiskMeasure}}`, `StoppingChain` holds `Vector{StoppingCriteria}`, `BanditDualityHandler` holds `Vector{DualityHandler}`. Each follows a three-phase construction: (a) validate the raw container key exists and is a non-empty vector, (b) iterate entries, resolve each via `__single_object_factory` or manual kind/params resolution, type-check the result against the parent abstract type, and accumulate built objects into a typed vector, (c) perform composite-level validation (weight sum for ConvexCombination, minimum count for BanditDualityHandler). The canonical implementation is `__build_convex_combination_internals!` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 623-716. This pattern should be reused for any future type that contains a heterogeneous list of subtypes.

### 3. Default-With-HasKey Backward Compatibility Pattern

New optional algorithm fields (sampling_scheme, duality_handler, forward_pass, cut_type) use a `haskey`-based default pattern in their builder functions: if the key is absent from the JSONC dict, inject a default instance directly and return true. This preserves backward compatibility with existing config files that lack these keys. The pattern is uniform across all four optional builders: `__build_sampling_scheme!`, `__build_duality_handler!`, `__build_forward_pass!`, `__build_cut_type!` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 526-580. The "before build" validator (`__validate_sddp_policy_task_definition_keys_types_before_build!` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input-validators.jl` lines 208-240) complements this by only validating the type if the key is present.

### 4. Conditional Kwargs Pattern in train.jl

The train pipeline builds a `Dict{Symbol,Any}` of keyword arguments and conditionally adds entries only when the user has configured a non-default option. This avoids passing explicit default values to SDDP.jl, which could cause version-compatibility issues or override SDDP.jl's own defaults. The pattern is: always include core kwargs (iteration_limit, stopping_rules, risk_measure, parallel_scheme, sampling_scheme, cut_type), then conditionally add duality_handler and forward_pass only if they are not `DefaultDuality`/`DefaultForwardPassStrategy`. The kwargs dict is then splatted: `SDDP.train(model; train_kwargs...)`. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/train.jl` lines 14-32.

### 5. Dual-Arity generate_sampling_scheme Pattern

`generate_sampling_scheme` has dual dispatch: a single-argument version for training (where depth comes from the scheme config) and a two-argument version with `graph_size::Integer` for simulation (where `DefaultSampling` needs to derive `max_depth` from the policy graph). Non-default schemes ignore the second argument and delegate to the single-argument version. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 309-341.

---

## Architectural Decisions

### D1: minimum_std instead of minimum_concentration for ModifiedChiSquared (chosen)

The ticket specified `minimum_concentration` as the field name for `ModifiedChiSquared`, matching the SDDP.jl constructor parameter name `minimum_concentration`. The implementation uses `minimum_std` instead, and maps it to `SDDP.ModifiedChiSquared(r.radius; minimum_std = r.minimum_std)`. This reflects the actual SDDP.jl API at the installed version, where the parameter is named `minimum_std`, not `minimum_concentration`. The deviation from the ticket was necessary to match the real SDDP.jl API. Visible in `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl` line 93 and `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` line 299.

### D2: WassersteinRM uses a norm function and GLPK.Optimizer (chosen) vs. solver-agnostic (rejected)

`SDDP.Wasserstein` requires a norm function and a solver for its inner optimization problem. The implementation hardcodes `x -> sum(abs, x)` (L1 norm) and `GLPK.Optimizer` as the solver. A solver-agnostic approach (passing the study's configured optimizer) was considered but rejected because the Wasserstein inner problem is a small LP that GLPK handles efficiently, and it avoids coupling the risk measure construction to the study's solver configuration. The hardcoded GLPK dependency is already in the project's dependencies. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` line 295.

### D3: RiskAdjustedForwardPassStrategy with hardcoded inner parameters (chosen) vs. configurable (deferred)

`SDDP.RiskAdjustedForwardPass` requires three inner parameters: a sub-forward-pass, a risk measure, and a resampling probability. The implementation hardcodes `DefaultForwardPass()`, `AVaR(0.5)`, and `resampling_probability=0.5`. Making these configurable would require a nested kind/params structure similar to ConvexCombination, adding significant complexity. The decision was to ship with sensible defaults and revisit configurability in a future ticket if research needs demand it. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 376-384.

### D4: Convergence.stopping_criteria always stored as Vector (chosen) vs. Union (rejected)

The ticket suggested `Union{StoppingCriteria, Vector{StoppingCriteria}}` for the stopping_criteria field. The implementation always normalizes to `Vector{StoppingCriteria}` during construction (single dict input is wrapped in a one-element vector). This eliminates branching downstream: `get_stopping_criteria` always returns a vector, and `train.jl` always uses a list comprehension over it. Visible in `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl` line 59 and `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 53-55.

### D5: OutOfSampleMC and Historical sampling deferred (chosen)

The ticket for sampling schemes listed OutOfSampleMonteCarlo and Historical as options. Both were deferred: OutOfSampleMC requires a separate scenario tree specification (complex JSONC structure), and Historical requires pre-computed scenario sequences. Only InSampleMC, PSRSampling, and DefaultSampling were implemented. The deferral was anticipated in the ticket's "Pitfalls to Avoid" section.

### D6: save_policy handles both single_cuts and multi_cuts via \_\_get_node_cutdata (chosen)

The `__get_node_cutdata` function in `/home/rogerio/git/sddp-lab/src/Engines/sddp/save_policy.jl` lines 15-19 inspects both `single_cuts` and `multi_cuts` arrays in the SDDP.jl JSON output and returns whichever is non-empty. This elegantly handles both SingleCut and MultiCut without needing separate code paths. The old TODO comment about multi-cut support was removed.

---

## Files and Structures Created

- No new source files were created; all new types and functions were added to existing files
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-sddp-mappings.jl` -- Extended with mapping tests for all new types: statistical stopping, simulation stopping, first-stage stopping, stopping chain, entropic, wasserstein, modified chi-squared, convex combination, single/multi cut (grew from ~80 to ~170 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-stopping-criteria.jl` -- New file with 182 lines, tests for Statistical, SimulationStopping, FirstStageStopping, StoppingChain construction and validation
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-convergence.jl` -- Extended with tests for multi-criteria convergence, stopping chain in convergence, empty criteria array, invalid inner criteria
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-risk-measure.jl` -- Extended with tests for Entropic, WassersteinRM, ModifiedChiSquared, ConvexCombination (grew from ~70 to ~363 lines)
- `/home/rogerio/git/sddp-lab/test/test-main.jl` -- Extended with 8 new integration pipeline tests: statistical stopping, multiple stopping criteria, explicit InSampleMC, strengthened conic duality, revisiting forward pass, risk-adjusted forward pass, multi-cut

---

## Conventions Adopted

### C1: Abstract type hierarchy per algorithm dimension

Each SDDP algorithm dimension gets its own abstract type: `StoppingCriteria`, `RiskMeasure`, `ParallelScheme`, `SamplingScheme`, `DualityHandler`, `ForwardPassStrategy`, `CutType`. All are defined in `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl`. Concrete types are subtypes. The `SDDPPolicyTaskDefinition` struct holds one field per dimension. This allows independent extension of each dimension without affecting others.

### C2: Default\* sentinel types for backward compatibility

Each optional algorithm dimension has a `Default*` type (`DefaultSampling`, `DefaultDuality`, `DefaultForwardPassStrategy`) that signals "use SDDP.jl's default behavior". In `train.jl`, the default type is detected via `isa` check and either omitted from kwargs or mapped to SDDP.jl's own default. `SingleCut` is the implicit default for cut_type but does not have a separate `DefaultCutType` -- it is always passed explicitly.

### C3: generate\_\* function naming convention

Every abstract type dimension has a `generate_TYPE_NAME` function that maps SDDPlab types to SDDP.jl types: `generate_stopping_rule`, `generate_risk_measure`, `generate_parallel_scheme`, `generate_sampling_scheme`, `generate_duality_handler`, `generate_forward_pass`, `generate_cut_type`. Each is a multi-method function with one method per concrete type. All are defined in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl`.

### C4: Integration tests construct objects directly, not from JSONC

Pipeline integration tests in `/home/rogerio/git/sddp-lab/test/test-main.jl` construct `SDDPPolicyTaskDefinition` and `SDDPSimulationTaskDefinition` directly with Julia constructors rather than parsing JSONC. This isolates the pipeline test from input parsing issues and makes the test self-documenting about which configuration is being tested. The `original` study is read once from the example directory, then a new `Study` is created with the custom engine configuration overlaid.

---

## Surprises and Deviations

### S1: ModifiedChiSquared parameter name mismatch

The ticket specified `minimum_concentration` as the second field, but the installed SDDP.jl version uses `minimum_std` as the keyword argument name. This was only discovered during `generate_risk_measure` implementation when calling `SDDP.ModifiedChiSquared()`. The struct, schema, tests, and JSONC config all use `minimum_std`. This highlights the importance of verifying SDDP.jl's actual API rather than relying solely on documentation or ticket specifications.

### S2: Wasserstein risk measure requires a norm function

The ticket mentioned `SDDP.Wasserstein(solver; alpha)` as the API, but the actual constructor is `SDDP.Wasserstein(norm, solver; alpha)` -- it requires a norm function as the first positional argument. The L1 norm `x -> sum(abs, x)` was chosen as a sensible default. Future refinement could expose the norm choice as a JSONC parameter.

### S3: SDDP.Statistical requires disable_warning=true

When using `SDDP.Statistical` stopping rule with short training runs (as in tests), SDDP.jl prints convergence warnings. The `disable_warning=true` keyword was added to suppress these during automated testing. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` line 248.

### S4: SimulationStoppingRule is a parametric type

`SDDP.SimulationStoppingRule` is a parametric type in SDDP.jl (parameterized on the sampling scheme type), so the mapping test checks `typeof(rule) <: SDDP.SimulationStoppingRule` rather than exact type equality. See `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-sddp-mappings.jl` line 28.

### S5: No separate test files per ticket for duality, forward pass, cut types

The tickets suggested creating separate test files (test-duality-handlers.jl, test-forward-passes.jl, test-cut-types.jl). The implementation consolidated duality handler, forward pass, and cut type tests into the existing `test-sddp-mappings.jl` and `test-engines.jl` files, and added pipeline integration tests to `test-main.jl`. This was a pragmatic decision to avoid test file proliferation for types that are simple enough to test in 5-10 lines each.

---

## Recommendations for Future Epics

### R1: Adding new algorithm options follows a now-proven recipe

For future SDDP options (e.g., cycle detection, log verbosity, print level), follow the six-step pattern demonstrated 20+ times in this epic: (1) add struct to `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl`, (2) add field to `SDDPPolicyTaskDefinition` or `SDDPSimulationTaskDefinition`, (3) add constructor in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` with schema if parameterized, (4) add `generate_*` method mapping to SDDP.jl, (5) add `__build_*!` function with haskey default, (6) wire through `train.jl`/`simulate.jl` kwargs dict.

### R2: Verify SDDP.jl API parameter names before implementing

Epic 02 discovered two parameter name mismatches between ticket specs and actual SDDP.jl APIs (minimum_concentration vs. minimum_std, Wasserstein norm argument). Future tickets should include a verification step where the implementer checks the SDDP.jl source or runs `methods(SDDP.TypeName)` in a Julia REPL before coding the constructor.

### R3: Nested composite types need careful error propagation

The `ConvexCombination`, `StoppingChain`, and `BanditDualityHandler` implementations show that iterating over entries and accumulating errors while building child objects is tricky to get right -- especially the `continue` pattern after each failure. The `__build_*_internals!` pattern (build all children, check all_valid flag) is the correct approach. Copy from `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` `__build_convex_combination_internals!` for any future composite types.

### R4: Pipeline integration tests are the most valuable Epic 02 addition

The 8 new pipeline tests in `/home/rogerio/git/sddp-lab/test/test-main.jl` (statistical stopping, multiple criteria, InSampleMC, strengthened duality, revisiting forward pass, risk-adjusted forward pass, multi-cut) exercise the full path from object construction through SDDP.train to SDDP.simulate. These caught issues that unit tests alone could not (e.g., the Wasserstein norm argument). Future epics should always include at least one pipeline test per new option.

### R5: Consider exposing RiskAdjustedForwardPass inner parameters

`RiskAdjustedForwardPassStrategy` currently hardcodes its inner risk measure (AVaR 0.5) and resampling probability (0.5). For serious research use, these should be configurable. The ConvexCombination pattern (nested kind/params with weight) provides the template for how to do this. This could be a follow-up ticket in a future epic.
