# ticket-020 Add Solver Configuration Options

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify solver parameter correctness for LP/MIP)

## Context

### Background

Currently, SDDPlab hardcodes `GLPK.Optimizer` as the solver, passed programmatically as an argument to the `build` function. Users who want to use HiGHS, Gurobi, CPLEX, or change solver parameters (tolerances, method selection, numeric focus) must modify Julia code. For a laboratory-style tool designed for experimentation, solver selection and configuration should be declarative via the JSONC config file, just like algorithm options.

### Relation to Epic

This is the fourth ticket in Epic 03. It completes the "numerical robustness" theme by giving users control over the solver backend and its numerical parameters. Combined with scaling (ticket-018) and diagnostics (ticket-019), users can tune the entire numerical stack: scale data, choose an appropriate solver, set tight tolerances, and verify conditioning -- all from JSONC.

### Current State

- `src/study.jl` defines `build(study::Study, optimizer)::Model` which passes the optimizer to `Lab.build`.
- `src/Engines/sddp/build.jl` passes the optimizer to `SDDP.PolicyGraph(...; optimizer = optimizer)`.
- All tests in `test/test-main.jl` and `test/test-study.jl` pass `GLPK.Optimizer` explicitly.
- `Project.toml` has `GLPK` as a dependency. No HiGHS dependency exists yet.
- The `SDDPEngine` struct does not hold any solver configuration.
- The current pattern is: user code calls `SDDPlab.build(study, GLPK.Optimizer)` -- the optimizer is external to the study config.

## Specification

### Requirements

1. **Add `SolverConfig` struct** to `src/Engines/Engines.jl`:
   - `solver_name::String` -- the solver to use. Supported values: `"GLPK"`, `"HiGHS"`. Extensible to others later.
   - `attributes::Dict{String, Any}` -- solver-specific attributes passed via `JuMP.set_attribute` (e.g., `{"msg_lev" => 0}` for GLPK, `{"output_flag" => false}` for HiGHS).

2. **Add JSONC configuration** for solver:
   - Optional `"solver"` key in the engine params, at the same level as `"policy"`, `"simulation"`, and `"diagnostics"`.
   - JSONC example:
     ```jsonc
     "solver": {
         "name": "GLPK",
         "attributes": {
             "msg_lev": 0
         }
     }
     ```
   - When the `"solver"` key is absent, default to `SolverConfig("GLPK", Dict{String,Any}())` (backward compatible).

3. **Create `src/Engines/sddp/solver.jl`** with:
   - A function `create_optimizer(config::SolverConfig)` that returns an optimizer factory (a callable) suitable for passing to `SDDP.PolicyGraph`.
   - The function resolves the solver name to the corresponding module, creates an `Optimizer`, and applies attributes:
     ```julia
     function create_optimizer(config::SolverConfig)
         if config.solver_name == "GLPK"
             return () -> begin
                 opt = GLPK.Optimizer()
                 for (k, v) in config.attributes
                     JuMP.set_attribute(opt, k, v)
                 end
                 return opt
             end
         elseif config.solver_name == "HiGHS"
             return () -> begin
                 opt = HiGHS.Optimizer()
                 for (k, v) in config.attributes
                     JuMP.set_attribute(opt, k, v)
                 end
                 return opt
             end
         else
             error("Unsupported solver: $(config.solver_name)")
         end
     end
     ```

4. **Add `solver` field to `SDDPEngine`**:
   - The `SDDPEngine` struct gets a `solver::SolverConfig` field.
   - Constructor defaults to `SolverConfig("GLPK", Dict{String,Any}())` when absent.

5. **Modify the build pipeline** to use the solver config:
   - Change `Lab.build(::SDDPEngine, files, optimizer)` to `Lab.build(::SDDPEngine, files)` -- the optimizer comes from the engine's solver config, not from the caller.
   - Update `src/study.jl`: `build(study::Study)::Model` (no optimizer argument). The study already contains the engine, which contains the solver config.
   - **Backward compatibility**: Keep the old `build(study::Study, optimizer)::Model` signature as a convenience overload that ignores the engine's solver config and uses the provided optimizer instead. Mark it with a deprecation warning.

6. **Add HiGHS as an optional dependency**:
   - Add HiGHS to `[deps]` in `Project.toml`.
   - Use conditional loading or a `try/catch` import so that HiGHS is only required when `"HiGHS"` is specified as the solver name.

### Inputs/Props

- `SolverConfig`: parsed from JSONC engine config.
- Solver attributes are passed as-is to `JuMP.set_attribute`; their validity depends on the solver backend.

### Outputs/Behavior

- When solver config is absent: GLPK is used with default settings (identical to current behavior).
- When solver config specifies `"GLPK"` with attributes: GLPK is used with those attributes.
- When solver config specifies `"HiGHS"`: HiGHS is used (requires HiGHS.jl to be installed).
- If a solver is specified but not available (package not installed), an informative error message is thrown during `create_optimizer`.

### Error Handling

- Unknown solver name: `ErrorException("Unsupported solver: XYZ. Supported solvers: GLPK, HiGHS")`.
- Solver package not installed: catch the `UndefVarError` and suggest `Pkg.add("HiGHS")`.
- Invalid solver attribute: let JuMP's error propagate (solver-specific attribute names are not validated by SDDPlab).
- Follow the established `CompositeException` pattern for JSONC parsing validation.

## Acceptance Criteria

- [ ] Given JSONC without a `"solver"` key, when the engine is parsed, then `SolverConfig("GLPK", Dict())` is used (backward compatible)
- [ ] Given `{"name": "GLPK", "attributes": {"msg_lev": 0}}`, when parsed, then a valid `SolverConfig` is returned
- [ ] Given `SolverConfig("GLPK", Dict())`, when `create_optimizer` is called, then it returns a callable that creates a GLPK optimizer
- [ ] Given `SolverConfig("GLPK", Dict("msg_lev" => 0))`, when the optimizer factory is called and the optimizer is used, then the attribute is applied
- [ ] Given `build(study)` (no optimizer argument), when called with a study that has `SolverConfig("GLPK", Dict())`, then the model is built successfully with GLPK
- [ ] Given `build(study, GLPK.Optimizer)` (old signature), when called, then a deprecation warning is logged and the model is built with the provided optimizer
- [ ] Given `SolverConfig("UnknownSolver", Dict())`, when `create_optimizer` is called, then an informative error is thrown
- [ ] Given the 1dtoy example with solver config `{"name": "GLPK", "attributes": {}}` in JSONC, when the pipeline runs, then it completes successfully

## Implementation Guide

### Suggested Approach

1. Add `SolverConfig` struct to `src/Engines/Engines.jl`:

   ```julia
   struct SolverConfig
       solver_name::String
       attributes::Dict{String, Any}
   end
   ```

2. Add `solver` field to `SDDPEngine`:

   ```julia
   struct SDDPEngine <: Engine
       policy::SDDPPolicyTaskDefinition
       simulation::SDDPSimulationTaskDefinition
       diagnostics::DiagnosticsConfig  # from ticket-019
       solver::SolverConfig
   end
   ```

   Note: If ticket-019 and ticket-020 are implemented in parallel, coordinate on the `SDDPEngine` field additions. If ticket-019 is implemented first, ticket-020 adds to the existing struct.

3. Add constructor and validators in `src/Engines/sddp/input.jl`:

   ```julia
   const SOLVER_CONFIG_SCHEMA = [
       FieldRule("name", String; constraints = [non_empty()]),
   ]

   function SolverConfig(d::Dict{String,Any}, e::CompositeException)
       valid = validate_schema!(d, SOLVER_CONFIG_SCHEMA, e)
       if !valid
           return nothing
       end
       attrs = get(d, "attributes", Dict{String,Any}())
       return SolverConfig(d["name"], attrs)
   end

   function __build_solver!(d::Dict{String,Any}, e::CompositeException)::Bool
       if !haskey(d, "solver")
           d["solver"] = SolverConfig("GLPK", Dict{String,Any}())
           return true
       end
       valid_key = __validate_key_types!(d, ["solver"], [Dict{String,Any}], e)
       if !valid_key
           return false
       end
       solver_d = d["solver"]
       d["solver"] = SolverConfig(solver_d, e)
       return d["solver"] !== nothing
   end
   ```

4. Create `src/Engines/sddp/solver.jl` with `create_optimizer` function.

5. Modify `src/Engines/sddp/build.jl`:
   - Add a method `Lab.build(engine::SDDPEngine, files::Vector{InputModule})::SDDPModel` that calls `create_optimizer(engine.solver)` and uses the result.
   - Keep the existing method signature with `optimizer` parameter for backward compat.

6. Modify `src/study.jl`:
   - Add `build(study::Study)::Model` that extracts solver config from the engine.
   - Deprecate `build(study::Study, optimizer)` with `Base.depwarn`.

7. Update `src/Engines/sddp.jl` to include `solver.jl`.

8. Add `HiGHS` to `Project.toml` `[deps]`. Use conditional import:
   ```julia
   function __get_solver_module(name::String)
       if name == "GLPK"
           return GLPK
       elseif name == "HiGHS"
           try
               return Base.require(Main, :HiGHS)
           catch
               error("HiGHS.jl is not installed. Run `Pkg.add(\"HiGHS\")` to install it.")
           end
       else
           error("Unsupported solver: $name. Supported solvers: GLPK, HiGHS")
       end
   end
   ```

### Key Files to Modify

- `src/Engines/Engines.jl` -- add `SolverConfig`, update `SDDPEngine`
- `src/Engines/sddp/input.jl` -- add `SolverConfig` constructor and `__build_solver!`
- `src/Engines/sddp/input-validators.jl` -- add `SOLVER_CONFIG_SCHEMA`, validators
- `src/Engines/sddp/solver.jl` -- **new file**, optimizer factory
- `src/Engines/sddp/build.jl` -- add new `Lab.build` overload without optimizer arg
- `src/Engines/sddp.jl` -- include `solver.jl`
- `src/study.jl` -- add `build(study)` overload, deprecate old signature
- `Project.toml` -- add HiGHS dependency
- `test/test-main.jl` -- update tests to use both old and new signatures
- `test/test-study.jl` -- update tests similarly
- `example/4ree/main.jsonc` (and other examples) -- optionally add `"solver"` key to demonstrate

### Patterns to Follow

- Optional field with `haskey` check and default value (same as `duality_handler`, `sampling_scheme`, etc.).
- Schema validation with `FieldRule` for the `name` field.
- The `attributes` dict is a free-form pass-through -- no schema validation needed (solver-specific).

### Pitfalls to Avoid

- SDDP.jl's `PolicyGraph` constructor expects an optimizer _factory_ (a callable that returns an optimizer), not an optimizer instance. The `create_optimizer` function must return `() -> SolverModule.Optimizer()`, not an instance directly.
- Solver attributes must be set on each optimizer instance, not on the factory. Set them inside the factory closure.
- GLPK attributes use integer codes (e.g., `GLPK.MSG_OFF = 0`, `GLPK.MSG_ERR = 1`). Users may pass string keys like `"msg_lev"` which GLPK expects as MOI attribute names. Use `MOI.RawOptimizerAttribute("msg_lev")` for GLPK attributes.
- HiGHS.jl may not be installed in all environments. The conditional import approach avoids a hard dependency.
- Changing `SDDPEngine` constructor affects all existing `SDDPEngine` construction calls in tests. Plan for this.
- Be careful about the interaction with ticket-019: both add fields to `SDDPEngine`. If implementing in parallel, one developer should add both fields.

## Testing Requirements

### Unit Tests

Create `test/Engines/sddp/test-solver.jl`:

- Test `SolverConfig` JSONC parsing with valid config (name + attributes).
- Test `SolverConfig` JSONC parsing with name only (no attributes -- defaults to empty dict).
- Test `SolverConfig` default when `"solver"` key is absent.
- Test `create_optimizer` with `SolverConfig("GLPK", Dict())` returns a callable.
- Test `create_optimizer` with `SolverConfig("GLPK", Dict("msg_lev" => 0))` and verify the optimizer has the attribute set.
- Test `create_optimizer` with unsupported solver name throws an error.
- Test `SDDPEngine` construction with and without solver config (backward compat).

### Integration Tests

- Run the 1dtoy example with `SolverConfig("GLPK", Dict())` via the new `build(study)` signature.
- Run the 1dtoy example with the deprecated `build(study, GLPK.Optimizer)` signature and verify deprecation warning.

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-016 (Epic 02 complete). Also soft-depends on ticket-019 for `SDDPEngine` struct coordination, but can be implemented independently if the struct changes are coordinated.
- **Blocks**: None

## Effort Estimate

**Points**: 3
**Confidence**: Medium
