# Epic 03 Learnings: Units and LP Conditioning

**Date**: 2026-02-17
**Scope**: Tickets 017-020
**Net change**: 4 new source files, 5 new test files, modifications to 8 existing source files

---

## Patterns Established

### 1. Input-Data Rescaling Pattern (Not LP-Level Transformation)

Scaling is applied as a preprocessing step on `SystemData` before model construction, NOT as a JuMP/SDDP model transformation. This is a deliberate architectural choice: SDDP.jl's cut generation relies on dual values from the model as-built, so post-hoc coefficient modification would corrupt cut quality. The function `apply_scaling` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` (lines 111-177) creates a new `SystemData` with all entity fields divided by their scaling factors, producing new `Bus`, `Line`, `Hydro`, and `Thermal` instances. The `Ref{Bus}` fields on scaled entities are re-linked to the scaled bus instances, not the originals. This pattern must be followed for any future scaling or normalization work.

### 2. Unified Hydro Balance Scaling Factor Pattern

Storage, flow, spillage, and inflow variables all share a single scaling factor (`s_hydro`) to preserve the hydro balance constraint `volume_out = volume_in - outflow + inflow`. The factor is `max(max_storage, max_flow)` across all hydros. This unification is computed in `compute_scaling_factors` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` (lines 22-81). Splitting these into separate factors would break the hydro balance equation by introducing inconsistent scaling on both sides of the constraint. A synthetic symbol `FLOW_SCALE` (defined on line 4) carries this unified factor for SAA scaling in `build.jl`.

### 3. Scaling-Aware Simulation Pipeline Pattern

Scaling information flows through the entire pipeline: `build.jl` stores `ScalingConfig` inside `SDDPModel` (line 13), `simulate.jl` propagates it to `SDDPSimulationTaskArtifact` (line 5), and `save_simulation.jl` unscales results before writing (line 11). The unscaling logic in `_unscale_simulations` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/save_simulation.jl` (lines 71-101) handles primal variables, state variables (with `.in`/`.out` fields), dual variables (which scale inversely), and composite cost variables (which scale as the product of cost and generation factors). The `_get_variable_unscale_factor` function (lines 44-69) centralizes the scaling-factor-to-variable mapping. Any future variable added to simulation output must have its unscale factor defined here.

### 4. Engine-Level Optional Config Pattern (Diagnostics, Solver)

Two new configuration structs (`DiagnosticsConfig`, `SolverConfig`) were added to `SDDPEngine` as engine-level optional fields (not inside `SDDPPolicyTaskDefinition`). They follow the same `haskey`-based backward compatibility pattern established in Epic 02, but at the engine level with dedicated `__build_diagnostics!` and `__build_solver!` functions in `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` (lines 16-87). This distinguishes algorithm-level configuration (in `SDDPPolicyTaskDefinition`) from infrastructure-level configuration (in `SDDPEngine`). Future engine-wide concerns (logging config, output formats, profiling flags) should follow this same engine-level optional pattern.

### 5. Optimizer Factory Pattern

`create_optimizer` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/solver.jl` (lines 7-41) returns a zero-argument closure that creates and configures an optimizer instance. SDDP.jl requires an optimizer factory (callable), not an optimizer instance. Attributes are set inside the closure via `MOI.set(opt, MOI.RawOptimizerAttribute(k), v)`, not via JuMP convenience functions, because the optimizer is a raw MOI object at that point. HiGHS support uses `Base.require(Main, :HiGHS)` for lazy loading -- the package need not be imported unless actually requested.

### 6. Metadata-Only Units Registry Pattern

The units infrastructure in `/home/rogerio/git/sddp-lab/src/Utils/units.jl` and `/home/rogerio/git/sddp-lab/src/Utils/variable-units.jl` is purely metadata -- it does NOT modify any existing type signatures, entity fields, or user-facing JSONC schemas. `PhysicalUnit` constants and `VARIABLE_UNITS_REGISTRY` are compile-time constants used for reporting and future diagnostics, not for runtime type safety. This was a deliberate constraint to avoid rewriting the type hierarchy. The `get_coefficient_magnitude_report` function traverses a JuMP model's registered variables and compares actual bounds against expected magnitude ranges from the registry.

---

## Architectural Decisions

### D1: ScalingMode on SDDPPolicyTaskDefinition, not SDDPEngine (chosen)

The `scaling` field is on `SDDPPolicyTaskDefinition`, not `SDDPEngine`. This was chosen because scaling is an algorithm-level concern that affects the SDDP policy construction (build step), not just infrastructure like solver or diagnostics. It follows the `kind_factory!` pattern for parameterless types (`NoScaling`, `AutoScaling`), consistent with `CutType`, `ParallelScheme`, etc. The alternative (engine-level field) was rejected because it would break the pattern where algorithm options live in the policy definition. Visible in `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl` lines 152-167.

### D2: Productivity scaling via ratio of generation and flow factors (chosen) vs. separate productivity factor (rejected)

When scaling hydro entities, productivity is adjusted as `prod_scaled = prod * s_flow / s_hgen` to maintain the relationship `gen = prod * flow` in scaled units. A separate productivity scaling factor was rejected because productivity is a derived quantity -- its scale is determined by the generation and flow scales. If those change, productivity must change accordingly. This logic is in `apply_scaling` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` line 151.

### D3: build(study) without optimizer argument as primary API (chosen), deprecated build(study, optimizer) (kept)

The new `build(study)` method in `/home/rogerio/git/sddp-lab/src/study.jl` (line 52) extracts the solver from the engine config and calls `create_optimizer`. The old `build(study, optimizer)` (line 56) remains with a `Base.depwarn` to avoid breaking existing user code. The two-argument `Lab.build(engine, files, optimizer)` still exists as the internal workhorse -- the new zero-optimizer `Lab.build(engine, files)` calls it after creating the optimizer from config. This layering preserves backward compatibility while making the optimizer-from-config path the default.

### D4: Text-based parsing of SDDP.numerical_stability_report (chosen with fallbacks) vs. JuMP constraint introspection (rejected)

The diagnostics module at `/home/rogerio/git/sddp-lab/src/Engines/sddp/diagnostics.jl` (lines 28-38) parses the text output of `SDDP.numerical_stability_report` using a regex to extract coefficient ranges `[lo, hi]`. This is fragile but pragmatic: `SDDP.numerical_stability_report` already does the heavy lifting of iterating all subproblem constraints and extracting coefficient ranges. The alternative (directly iterating `JuMP.all_constraints` on each subproblem) would duplicate SDDP.jl's internal logic. If the report text format changes in a future SDDP.jl version, the regex may need updating, but the function gracefully falls back (lines 41-44) by skipping threshold checks when no ranges are found.

### D5: DiagnosticsConfig and SolverConfig at engine level, not policy level (chosen)

Both `DiagnosticsConfig` and `SolverConfig` were added to `SDDPEngine` rather than to `SDDPPolicyTaskDefinition`. The rationale is that these are infrastructure concerns (which solver to use, whether to run diagnostics) rather than algorithm concerns (how to train the SDDP policy). This creates a clear separation: policy-level options affect SDDP.jl's algorithmic behavior, engine-level options affect the execution environment. Visible in `/home/rogerio/git/sddp-lab/src/Engines/Engines.jl` lines 196-201.

---

## Files and Structures Created

- `/home/rogerio/git/sddp-lab/src/Utils/units.jl` -- `PhysicalUnit` struct, 8 predefined unit constants, `UnitConversion` struct, `UNIT_CONVERSIONS` dict (29 lines)
- `/home/rogerio/git/sddp-lab/src/Utils/variable-units.jl` -- `VariableUnitInfo` struct, `VARIABLE_UNITS_REGISTRY` dict, `get_variable_unit`, `get_coefficient_magnitude_report` with helpers for bound extraction and magnitude ratio computation (138 lines)
- `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` -- `ScalingConfig` accessors, `compute_scaling_factors`, `apply_scaling`, `no_scaling_config`, `get_scaling_factor` (177 lines)
- `/home/rogerio/git/sddp-lab/src/Engines/sddp/diagnostics.jl` -- `run_diagnostics`, `Lab.diagnose` implementation (63 lines)
- `/home/rogerio/git/sddp-lab/src/Engines/sddp/solver.jl` -- `create_optimizer` with GLPK/HiGHS support (42 lines)
- `/home/rogerio/git/sddp-lab/test/Utils/test-units.jl` -- Tests for PhysicalUnit, UnitConversion, UNIT_CONVERSIONS roundtrip (155 lines)
- `/home/rogerio/git/sddp-lab/test/Utils/test-variable-units-report.jl` -- Tests for get_coefficient_magnitude_report with bounded, unbounded, empty, and mixed models (167 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-scaling.jl` -- Tests for JSONC parsing, compute_scaling_factors, apply_scaling, unscaling (351 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-diagnostics.jl` -- Tests for DiagnosticsConfig parsing, run_diagnostics behavior, SDDPEngine integration (255 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-solver.jl` -- Tests for SolverConfig parsing, create_optimizer, SDDPEngine integration (228 lines)

---

## Conventions Adopted

### C1: Synthetic scaling symbol keys for cross-cutting factors

When a scaling factor applies to multiple variables or to a concept not directly tied to a single variable symbol, a synthetic `Symbol` key is used: `FLOW_SCALE = Symbol("FLOW_SCALE")` and `COST_SCALE = Symbol("COST_SCALE")` in `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` (lines 3-4). These are distinct from the `Lab.STORED_VOLUME`, `Lab.HYDRO_GENERATION` etc. symbols that map to JuMP variables. Future scaling extensions should follow this convention for any factor that does not correspond 1:1 to a JuMP variable name.

### C2: Engine-level optional config follows the same \__build_\*! pattern as policy-level options

`__build_diagnostics!` and `__build_solver!` are structurally identical to `__build_duality_handler!`, `__build_forward_pass!`, etc.: check `haskey`, inject default if absent, validate dict type, construct from dict, assign back. The `__build_sddp_engine_internals_from_dicts!` function at `/home/rogerio/git/sddp-lab/src/Engines/input-validators.jl` (lines 21-29) chains them together with `&&`. Future engine-level configs should add another `__build_*!` and another line to this function.

### C3: Cross-field validation for config structs

`DiagnosticsConfig` has a cross-field constraint (`halt_threshold >= warn_threshold`) validated by `__validate_diagnostics_halt_ge_warn!` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/input-validators.jl` (lines 88-101). This follows the same pattern as `__validate_convergence_min_max!` from Epic 01. The pattern is: schema validates individual fields first, then a separate cross-field validator runs only if schema passed.

### C4: Simulation unscaling is centralized in save_simulation.jl

All unscaling of simulation results happens in `_unscale_simulations` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/save_simulation.jl`, not in the simulation step itself. This ensures that the SDDP simulation operates on scaled values (consistent with training), and only the final output is converted back to physical units.

---

## Surprises and Deviations

### S1: SDDP.numerical_stability_report IO parameter changed

The ticket spec suggested `SDDP.numerical_stability_report(model; io = io)` as the API. The actual SDDP.jl API takes the IO object as the first positional argument: `SDDP.numerical_stability_report(io, model; print = true, warn = true)`. This was discovered during implementation and adjusted in `/home/rogerio/git/sddp-lab/src/Engines/sddp/diagnostics.jl` (line 16). This reinforces the Epic 02 learning: always verify SDDP.jl API signatures before coding.

### S2: Unified storage/flow factor was not in the original ticket spec

Ticket-018 suggested separate scaling factors for storage, flow, and spillage. During implementation, it became clear that the hydro balance constraint `v_out = v_in - outflow + inflow` requires all terms to use the same scaling factor. Splitting them would create an inconsistent constraint. The implementation unified them under `s_hydro = max(max_storage, max_flow)` in `compute_scaling_factors`. This is the most impactful deviation: it simplifies the scaling math but means very large reservoirs (50000 hm3) will dominate the flow scale even if actual flows are small (250 hm3/period).

### S3: Cost scaling required compound adjustments for objective coefficients

The ticket spec for scaling suggested dividing costs by a cost factor. In practice, the stage objective has terms like `cost * generation`, so the objective coefficient is `cost_scaled * gen_scaled = (cost/s_cost) * (gen/s_gen)`. To keep the objective in a well-conditioned range, penalty coefficients (spillage_penalty, exchange_penalty) needed compound scaling: `pen_scaled = pen * s_flow / (s_cost * s_gen)`. This compound scaling logic in `apply_scaling` at lines 128-157 was not anticipated in the ticket and required careful algebraic derivation to ensure the objective function remains correct after unscaling.

### S4: SDDPModel struct gained a scaling field

The original `SDDPModel` held only `policy_graph::SDDP.PolicyGraph`. To support unscaling simulation results, it was extended to `SDDPModel(policy_graph, scaling::ScalingConfig)`. This required updating all existing code that constructs `SDDPModel` and the `SDDPSimulationTaskArtifact` struct which now also carries a `ScalingConfig`. The ripple effect was contained to the engine module but required coordinating changes across `build.jl`, `simulate.jl`, and `save_simulation.jl`.

### S5: SAA (scenario tree) values also need scaling

Beyond entity parameters, the SAA (Sample Average Approximation) inflow values generated in `__generate_subproblem_builder` also needed scaling. The implementation divides SAA values by `FLOW_SCALE` before using them as realizations in `SDDP.parameterize`. Similarly, load values in `__add_load_balance!` are divided by the generation scale factor. These adjustments at `/home/rogerio/git/sddp-lab/src/Engines/sddp/build.jl` (lines 304-309, 367) were not anticipated in the ticket but are essential for consistent scaled model construction.

---

## Recommendations for Future Epics

### R1: Adding new system elements (Epic 05) must update scaling.jl

When adding renewables, batteries, or demand response, `compute_scaling_factors` at `/home/rogerio/git/sddp-lab/src/Engines/sddp/scaling.jl` must be updated to include new variable categories. Likewise, `apply_scaling` must create scaled versions of new entity types, and `_get_variable_unscale_factor` in `save_simulation.jl` must map new variables to their unscale factors.

### R2: Adding new simulation output variables must update the unscaling map

The `_get_variable_unscale_factor` function in `/home/rogerio/git/sddp-lab/src/Engines/sddp/save_simulation.jl` (lines 44-69) uses a chain of `if/elseif` to map variable symbols to unscale factors. Any new variable recorded in simulation output (via the `SDDP.simulate` call in `simulate.jl`) must be added to this function. Forgetting to do so will cause the variable to be written at scaled values (incorrect).

### R3: The diagnose step is optional and manual -- consider auto-running

The `diagnose` function in `/home/rogerio/git/sddp-lab/src/study.jl` (line 65) exists but is not automatically called in the build-train pipeline. It must be called explicitly by the user or test code. A future ticket could wire it into the pipeline between build and train, controlled by the `DiagnosticsConfig.run_numerical_report` flag, so that users get automatic numerical stability feedback.

### R4: HiGHS dependency is lazy-loaded but not tested

HiGHS support in `create_optimizer` uses `Base.require(Main, :HiGHS)` for lazy loading. There are no tests exercising the HiGHS path because the test environment may not have HiGHS installed. When HiGHS is added as a test dependency, an integration test should verify `create_optimizer(SolverConfig("HiGHS", Dict()))` produces a working optimizer.

### R5: The variable units registry should be extended when new variables are added

`VARIABLE_UNITS_REGISTRY` at `/home/rogerio/git/sddp-lab/src/Utils/variable-units.jl` (lines 8-19) currently covers the original 10 variables. When new system elements add new variables (renewable generation, battery state of charge, demand response curtailment), entries must be added to this registry for the magnitude reporting to cover them.
