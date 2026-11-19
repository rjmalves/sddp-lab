# ticket-017 Implement Variable Units Registry and Validation

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: `sddp-specialist` (verify unit choices match energy systems conventions)

## Context

### Background

SDDPlab models involve quantities with different physical units: MW for generation, hm3 for reservoir storage, m3/s or hm3/period for flows, $/MWh for costs, hours for time. When these quantities appear as LP coefficients, magnitude mismatches (e.g., a 10,000 hm3 reservoir paired with a 0.001 $/MWh marginal cost) cause numerical conditioning problems. The first step toward addressing this is establishing a units registry that formally documents what units each variable and parameter uses, enables validation that unit assumptions are consistent, and provides conversion factors that ticket-018 (scaling) can use.

This ticket does NOT change any existing data types or require users to annotate units in their JSONC files. It creates an internal registry that codifies the unit assumptions already implicit in the model, and provides utility functions for unit conversion and magnitude reporting.

### Relation to Epic

This is the first ticket in Epic 03 (Units & LP Conditioning). It establishes the unit metadata infrastructure that subsequent tickets (LP scaling, diagnostics) will build on. The registry gives the scaling system (ticket-018) the conversion factors it needs, and gives the diagnostics system (ticket-019) a way to report coefficient magnitudes in meaningful physical terms.

### Current State

- System entity structs (`Hydro`, `Thermal`, `Bus`, `Line` in `src/System/System.jl`) use plain `Real` fields with no unit annotations.
- Variable symbols are defined in `src/Lab/variables.jl` as plain `Symbol` constants (e.g., `STORED_VOLUME`, `THERMAL_GENERATION`).
- The model builder in `src/Engines/sddp/build.jl` creates JuMP variables with bounds from entity fields but no unit metadata.
- No unit-related infrastructure exists anywhere in the codebase.

## Specification

### Requirements

1. **Create `src/Utils/units.jl`** with:
   - A `PhysicalUnit` struct representing a unit (name, symbol string, and a base-unit category).
   - A set of predefined unit constants for energy systems: `MW`, `MWh`, `HM3`, `M3_PER_S`, `DOLLAR_PER_MWH`, `DOLLAR`, `HOURS`, `DIMENSIONLESS`.
   - A `UnitConversion` struct holding a source unit, target unit, and conversion factor.
   - A `UNIT_CONVERSIONS` dictionary of known conversions (e.g., m3/s to hm3/month given a period length).

2. **Create `src/Utils/variable-units.jl`** with:
   - A `VariableUnitInfo` struct associating a variable symbol (`Symbol`) with its expected `PhysicalUnit` and a typical magnitude range (`min_magnitude::Float64`, `max_magnitude::Float64`).
   - A `VARIABLE_UNITS_REGISTRY` constant `Dict{Symbol, VariableUnitInfo}` mapping each variable symbol from `src/Lab/variables.jl` to its expected unit and typical magnitude range.
   - A function `get_variable_unit(sym::Symbol)::Union{VariableUnitInfo, Nothing}` to look up a variable's unit info.
   - A function `get_coefficient_magnitude_report(model::JuMP.Model)::DataFrame` that iterates over registered variables in a JuMP model and reports: variable name, unit, actual bound range, expected magnitude range, and a ratio indicating potential scaling concern (actual/expected).

3. **Register units for all existing variables**:
   - `STORED_VOLUME`: HM3, typical range [0, 100000]
   - `HYDRO_GENERATION`: MW, typical range [0, 10000]
   - `THERMAL_GENERATION`: MW, typical range [0, 10000]
   - `TURBINED_FLOW`: HM3 (per period), typical range [0, 10000]
   - `SPILLAGE`: HM3 (per period), typical range [0, 50000]
   - `INFLOW`: HM3 (per period), typical range [0, 10000]
   - `DEFICIT`: MW, typical range [0, 50000]
   - `LOAD`: MW, typical range [0, 50000]
   - `DIRECT_EXCHANGE`, `REVERSE_EXCHANGE`: MW, typical range [0, 10000]

4. **Include the new files** in `src/Utils/Utils.jl` and export the public API.

### Inputs/Props

- No user-facing inputs. This is internal infrastructure.
- The registry is a compile-time constant populated from hardcoded domain knowledge.

### Outputs/Behavior

- `get_variable_unit(:STORED_VOLUME)` returns `VariableUnitInfo(:STORED_VOLUME, HM3, 0.0, 100000.0)`.
- `get_coefficient_magnitude_report(model)` returns a DataFrame with one row per registered variable that exists in the model, showing actual vs. expected magnitude ranges.
- Variables not found in the model are silently skipped (not all variables exist in every subproblem configuration).

### Error Handling

- `get_variable_unit` returns `nothing` for unregistered symbols (no error).
- `get_coefficient_magnitude_report` catches JuMP errors when querying variable bounds and reports `NaN` for unbounded variables.

## Acceptance Criteria

- [ ] Given the `PhysicalUnit` struct, when `MW` is accessed, then it has `name = "megawatt"`, `symbol = "MW"`, `category = :power`
- [ ] Given the `VARIABLE_UNITS_REGISTRY`, when `get_variable_unit(:STORED_VOLUME)` is called, then it returns a `VariableUnitInfo` with unit `HM3`
- [ ] Given the `VARIABLE_UNITS_REGISTRY`, when `get_variable_unit(:NONEXISTENT)` is called, then it returns `nothing`
- [ ] Given a JuMP model with `STORED_VOLUME` variables bounded in [0, 50000], when `get_coefficient_magnitude_report(model)` is called, then the report contains one row for `STORED_VOLUME` with the correct actual bounds and a magnitude ratio
- [ ] Given the `UNIT_CONVERSIONS` dict, when looking up conversion from `M3_PER_S` to `HM3` with a period of 730 hours (monthly), then a valid conversion factor is returned
- [ ] Given all existing variables in `src/Lab/variables.jl`, when checking the registry, then at least `STORED_VOLUME`, `HYDRO_GENERATION`, `THERMAL_GENERATION`, `DEFICIT`, `TURBINED_FLOW`, `SPILLAGE`, `INFLOW` are registered

## Implementation Guide

### Suggested Approach

1. Create `src/Utils/units.jl`:

   ```julia
   struct PhysicalUnit
       name::String
       symbol::String
       category::Symbol  # :power, :volume, :flow, :cost, :time, :dimensionless
   end

   const MW = PhysicalUnit("megawatt", "MW", :power)
   const MWh = PhysicalUnit("megawatt-hour", "MWh", :energy)
   const HM3 = PhysicalUnit("cubic hectometer", "hm3", :volume)
   const M3_PER_S = PhysicalUnit("cubic meters per second", "m3/s", :flow)
   const DOLLAR_PER_MWH = PhysicalUnit("dollars per megawatt-hour", "\$/MWh", :cost_rate)
   const DOLLAR = PhysicalUnit("dollars", "\$", :cost)
   const HOURS = PhysicalUnit("hours", "h", :time)
   const DIMENSIONLESS = PhysicalUnit("dimensionless", "-", :dimensionless)
   ```

2. Create `src/Utils/variable-units.jl`:

   ```julia
   struct VariableUnitInfo
       variable::Symbol
       unit::PhysicalUnit
       min_magnitude::Float64
       max_magnitude::Float64
   end

   const VARIABLE_UNITS_REGISTRY = Dict{Symbol, VariableUnitInfo}(
       STORED_VOLUME => VariableUnitInfo(STORED_VOLUME, HM3, 0.0, 100_000.0),
       # ... etc
   )
   ```

3. Implement `get_coefficient_magnitude_report` using `JuMP.all_variables(model)`, `JuMP.name(v)`, `JuMP.has_lower_bound(v)`, `JuMP.lower_bound(v)`, `JuMP.has_upper_bound(v)`, `JuMP.upper_bound(v)`.

4. Include both files in `src/Utils/Utils.jl` after `schema.jl`.

5. Export: `PhysicalUnit`, `VariableUnitInfo`, `get_variable_unit`, `get_coefficient_magnitude_report`, and the unit constants.

### Key Files to Modify

- `src/Utils/units.jl` -- **new file**, physical unit definitions and conversions
- `src/Utils/variable-units.jl` -- **new file**, variable-unit registry and magnitude reporting
- `src/Utils/Utils.jl` -- add `include` and `export` statements

### Patterns to Follow

- Follow the `FieldRule`/`FieldConstraint` pattern from `src/Utils/schema.jl`: simple structs, predefined constants, exported functions.
- Use `const` for all registry data (compile-time, immutable).
- Variable symbols reference the constants from `src/Lab/variables.jl` (e.g., `STORED_VOLUME`, not `Symbol("STORAGE")`).

### Pitfalls to Avoid

- Do NOT make units a parametric type on the system entity structs -- that would require rewriting the entire type hierarchy. Units are metadata only.
- Do NOT require units in JSONC input files. The registry is internal-only for now.
- The variable symbols in `variables.jl` map to specific JuMP variable names via `base_name`. When querying JuMP variables, match on the `Symbol` key in the model dictionary (e.g., `model[STORED_VOLUME]`), not on string names.
- `STORED_VOLUME` is defined as `Symbol("STORAGE")` in `variables.jl` -- be careful to use the Julia constant, not the string.
- The `get_coefficient_magnitude_report` function receives a `JuMP.Model` (a single subproblem), not the full `SDDP.PolicyGraph`. The caller is responsible for extracting a representative subproblem.

## Testing Requirements

### Unit Tests

Create `test/Utils/test-units.jl`:

- Test `PhysicalUnit` struct construction and field access for all predefined units.
- Test `VariableUnitInfo` struct construction.
- Test `get_variable_unit` returns correct info for registered variables.
- Test `get_variable_unit` returns `nothing` for unregistered symbols.
- Test `VARIABLE_UNITS_REGISTRY` has entries for all expected variables.
- Test unit conversion lookup for known conversions (m3/s to hm3).

### Integration Tests

Create `test/Utils/test-variable-units-report.jl`:

- Build a simple JuMP model with bounded variables named after SDDPlab symbols.
- Call `get_coefficient_magnitude_report` and verify the DataFrame has correct columns and rows.
- Verify that unbounded variables report `NaN` or `Inf` appropriately.

### E2E Tests

- N/A (no user-facing behavior changes)

## Dependencies

- **Blocked By**: ticket-016 (Epic 02 complete)
- **Blocks**: ticket-018

## Effort Estimate

**Points**: 2
**Confidence**: High
