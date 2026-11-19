# ticket-031 Add Multivariate Stochastic Process Support

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify sampling performance and allocation-free hot paths)

## Context

### Background

The current stochastic process framework supports two process types: `Naive` (copula-correlated marginal distributions) and `AutoRegressive` (univariate PAR(p) per element, with a Naive noise model that handles cross-element correlation via copulas). However, the `AutoRegressive` type models each element's signal independently -- the AR coefficients are per-element with no cross-element interaction in the signal model. This means the current system cannot represent a Vector AutoRegressive (VAR) model where the inflow of hydro plant A at time t depends on the lagged inflow of hydro plant B.

This ticket adds a `VectorAutoRegressive` stochastic process type that models the full cross-correlation structure through coefficient matrices (Phi_1, Phi_2, ..., Phi_p) rather than per-element scalar coefficients. This is the standard approach for multi-basin hydro systems where rivers share watersheds.

### Relation to Epic

Epic 07 (Advanced Stochastic Modeling) extends the stochastic modeling capabilities. This ticket is the foundation: it adds the VAR(p) process type that ticket-032 (Markov chain states) will later augment with regime-switching parameters, and that ticket-033 (out-of-sample validation) will test against independent scenario sets.

### Current State

- `src/StochasticProcess/StochasticProcess.jl`: Defines `AbstractStochasticProcess`, `generate_saa`, `add_inflow_uncertainty!`, `__generate_saa` interfaces. Exports `Naive`, `AutoRegressive`.
- `src/StochasticProcess/autoregressive.jl`: `AutoRegressive` struct holds `Vector{UnivariateAutoRegressive}` (one per hydro) and a `Naive` noise model. Each `UnivariateAutoRegressive` has scalar `phis` coefficients and `scale` (mean, std). The `add_inflow_uncertainty!` method for `AutoRegressive` creates per-element SDDP state variables (`STCHP`), per-element AR recurrence constraints, and links to `INFLOW`. SAA generation delegates to the Naive noise model.
- `src/StochasticProcess/autoregressive-validators.jl`: Validates per-element AR parameter dicts with keys `["season", "coefficients", "residual_variance", "scale_parameters"]`.
- `src/Scenarios/inflow-validators.jl`: `__build_stochastic_process!` uses `__kind_factory!` to resolve `{"kind": "AutoRegressive", "params": {...}}` to the correct type.
- `src/Engines/sddp/build.jl`: `add_inflow_uncertainty!(m, s::AutoRegressive, season, method)` creates `STCHP` state variables, AR constraints, and inflow coupling. `generate_saa(scenarios, num_stages, seed)` calls through to the stochastic process. The `__generate_subproblem_builder` closure captures the SAA and parameterizes `omega_INFLOW`.
- The `__kind_factory!` mechanism resolves `{"kind": "TypeName", "params": {...}}` to `TypeName(params_dict, error_accumulator)`.

## Specification

### Requirements

1. **New type `VectorAutoRegressive <: AbstractStochasticProcess`** that represents a VAR(p) model: `X_t = mu_s + Phi_{s,1} * (X_{t-1} - mu_{s-1}) + ... + Phi_{s,p} * (X_{t-p} - mu_{s-p}) + epsilon_t` where `s` is the season, `Phi_{s,l}` are N x N coefficient matrices, `mu_s` are N-vectors of means, and `epsilon_t ~ SklarDist(copula_s, marginals_s)`.
2. **Periodic VAR**: Support season-dependent parameters (coefficient matrices, scales, noise distributions) or a single set of parameters used for all seasons, matching the existing `SimpleARparameters` / `PeriodicARparameters` pattern.
3. **SAA generation**: `__generate_saa` for `VectorAutoRegressive` delegates to the embedded `Naive` noise model (same as `AutoRegressive` does today).
4. **Subproblem integration**: `add_inflow_uncertainty!(m, s::VectorAutoRegressive, season, method)` creates `STCHP` state variables (one per element per lag, as today), `omega_INFLOW` noise variables, and VAR recurrence constraints with matrix coefficients. Must support all `InflowNonNegativity` methods (`InflowNone`, `InflowPenalty`, `InflowTruncation`, `InflowTruncationWithPenalty`).
5. **JSONC configuration**: The process is specified via `{"kind": "VectorAutoRegressive", "params": {...}}` where `params` contains `"marginal_models"` (same structure as `AutoRegressive` for backward compatibility in scale/initial values), `"copulas"`, and a new `"coefficient_matrices"` key.
6. **Backward compatibility**: The existing `AutoRegressive` type must continue to work unchanged. `VectorAutoRegressive` is a new option.

### Inputs/Props

JSONC `params` dict structure:

```jsonc
{
  "kind": "VectorAutoRegressive",
  "params": {
    "marginal_models": [
      {
        "id": 1,
        "initial_values": [100.0, 110.0],
        "models": [
          {
            "season": 1,
            "residual_variance": 0.04,
            "scale_parameters": [150.0, 20.0], // [mean, std]
          },
          {
            "season": 2,
            "residual_variance": 0.05,
            "scale_parameters": [180.0, 25.0],
          },
        ],
      },
      {
        "id": 2,
        "initial_values": [80.0, 90.0],
        "models": [
          {
            "season": 1,
            "residual_variance": 0.03,
            "scale_parameters": [120.0, 15.0],
          },
          {
            "season": 2,
            "residual_variance": 0.04,
            "scale_parameters": [140.0, 20.0],
          },
        ],
      },
    ],
    "copulas": [
      { "kind": "IndependentCopula", "parameters": [2] },
      { "kind": "IndependentCopula", "parameters": [2] },
    ],
    "coefficient_matrices": [
      {
        "season": 1,
        "lag": 1,
        "matrix": [
          [0.5, 0.1],
          [0.2, 0.4],
        ],
      },
      {
        "season": 1,
        "lag": 2,
        "matrix": [
          [0.1, 0.0],
          [0.0, 0.1],
        ],
      },
      {
        "season": 2,
        "lag": 1,
        "matrix": [
          [0.6, 0.15],
          [0.1, 0.5],
        ],
      },
      {
        "season": 2,
        "lag": 2,
        "matrix": [
          [0.05, 0.0],
          [0.0, 0.05],
        ],
      },
    ],
  },
}
```

Note: The `marginal_models` no longer carry per-element `"coefficients"` -- those are replaced by the `"coefficient_matrices"`. The `"residual_variance"` is still per-element for the noise model construction.

### Outputs/Behavior

- `VectorAutoRegressive` constructs successfully from a valid JSONC params dict
- `generate_saa` produces noise scenarios with correct dimensions `[num_stages][num_branchings][num_elements]`
- `add_inflow_uncertainty!` creates:
  - `STCHP` state variables: `[1:stchp_size]` where `stchp_size = N * max_lag` (N = number of elements)
  - VAR recurrence constraints: `(STCHP[i_n].out - mu_s[n]) / sigma_s[n] = sum_l sum_m Phi_{s,l}[n,m] * (STCHP[i_m + l - 1].in - mu_{s-l}[m]) / sigma_{s-l}[m] + omega_INFLOW[n] [+ slack]`
  - Inflow coupling: `INFLOW[n] = STCHP[i_n].out [+ slack]` respecting `InflowNonNegativity` methods
  - Memory shift: `STCHP[n].out == STCHP[n-1].in` for non-current-lag states

### Error Handling

- Missing `coefficient_matrices` key: accumulate `ErrorException` via `CompositeException`
- Mismatched matrix dimensions (not N x N): accumulate `AssertionError`
- Inconsistent lag counts between coefficient_matrices and marginal_models initial_values: accumulate `AssertionError`
- Missing season entries: accumulate `AssertionError`
- Follow the existing `build_internals -> validate_keys_types -> validate_content -> validate_consistency` pipeline

## Acceptance Criteria

- [ ] Given a JSONC with `"kind": "VectorAutoRegressive"` and valid params, when the stochastic process is constructed, then a `VectorAutoRegressive` object is returned with correct coefficient matrices, scales, and noise model.
- [ ] Given a `VectorAutoRegressive` with 2 elements and lag 2, when `generate_saa` is called with seed, initial_season, N stages, B branchings, then the output has dimensions `[N][B][2]` and is reproducible with the same seed.
- [ ] Given a `VectorAutoRegressive` with 2 elements and lag 1, when `add_inflow_uncertainty!` is called with `InflowNone`, then the JuMP model contains 2 STCHP state variables, 2 omega_INFLOW variables, 2 INFLOW variables, and 2 AR recurrence constraints with off-diagonal terms.
- [ ] Given a `VectorAutoRegressive` with 2 elements and lag 2, when `add_inflow_uncertainty!` is called, then the JuMP model contains 4 STCHP state variables (2 elements x 2 lags) and 2 memory shift constraints.
- [ ] Given a `VectorAutoRegressive`, when `add_inflow_uncertainty!` is called with `InflowPenalty`, then `INFLOW_SLACK` variables are created and `INFLOW >= 0` bounds are set.
- [ ] Given a `VectorAutoRegressive`, when `add_inflow_uncertainty!` is called with `InflowTruncationWithPenalty`, then `NOISE_ADJUSTMENT_SLACK` variables are created and integrated into the AR recurrence.
- [ ] Given a JSONC with `"kind": "VectorAutoRegressive"` and a coefficient matrix of wrong dimensions, when the stochastic process is constructed, then construction returns `nothing` and the `CompositeException` contains a descriptive error.
- [ ] Given the existing `AutoRegressive` type, when used in JSONC, then it continues to work exactly as before (no regression).

## Implementation Guide

### Suggested Approach

1. **Create `src/StochasticProcess/vectorautoregressive-validators.jl`**: Define validation functions for the VAR-specific params dict. Validate `coefficient_matrices` entries: each must have `season` (Int, positive), `lag` (Int, positive), `matrix` (Matrix{Float64} of size N x N). Validate consistency: all seasons in marginal_models must have corresponding coefficient_matrices entries. Validate dimensions: matrix size must match number of marginal_models.

2. **Create `src/StochasticProcess/vectorautoregressive.jl`**: Define internal types and the main struct:
   - `VARSeasonParameters`: holds coefficient matrices for all lags for one season, plus scale vectors
   - `VectorAutoRegressive <: AbstractStochasticProcess`: holds `VARSeasonParameters` per season, `Naive` noise model, element IDs, initial values, max lag
   - Constructor `VectorAutoRegressive(d::Dict{String,Any}, e::CompositeException)`: parse `marginal_models` for IDs/scales/initial_values (reuse existing `UnivariateAutoRegressive` parsing where possible for scales), parse `coefficient_matrices` into per-season matrices, build `Naive` noise model from residual variances + copulas (reuse `__build_noise_naive_dict` pattern from `autoregressive.jl`)
   - Implement `__get_ids`, `length`, `size`, `__generate_saa` (delegate to noise model)
   - Implement `add_inflow_uncertainty!(m, s::VectorAutoRegressive, season, method)`:
     - Create `STCHP` states: N \* max_lag total, indexed as `[(elem_1, lag_1), (elem_1, lag_2), ..., (elem_N, lag_max)]` matching the existing `AutoRegressive` layout
     - VAR recurrence: for each element `n`, the constraint involves `Phi[n, m]` terms coupling across elements
     - Support all `InflowNonNegativity` methods by following the exact same branching pattern as `add_inflow_uncertainty!(m, s::AutoRegressive, ...)` in `build.jl`

3. **Update `src/StochasticProcess/StochasticProcess.jl`**: Add `include("vectorautoregressive-validators.jl")` and `include("vectorautoregressive.jl")`. Add `VectorAutoRegressive` and any accessors to the `export` list.

4. **No changes to `src/Engines/sddp/build.jl`**: The existing `generate_saa(scenarios, ...)` and `add_uncertainties!(m, scenarios, node, method)` are generic -- they call through `add_inflow_uncertainty!(m, inflow, season, method)` which dispatches on the stochastic process type. Since `VectorAutoRegressive <: AbstractStochasticProcess`, no modifications to the build pipeline are needed.

5. **No changes to `src/Scenarios/inflow-validators.jl`**: The `__kind_factory!` mechanism resolves `"VectorAutoRegressive"` automatically since the type will exist in the `StochasticProcess` module.

### Key Files to Modify

- **New**: `src/StochasticProcess/vectorautoregressive-validators.jl`
- **New**: `src/StochasticProcess/vectorautoregressive.jl`
- **Modify**: `src/StochasticProcess/StochasticProcess.jl` (add includes and exports)
- **New**: `test/StochasticProcess/test-vectorautoregressive.jl`

### Patterns to Follow

- Follow the `AutoRegressive` constructor pattern: parse marginal_models, build noise model, validate dimensions
- Follow the `add_inflow_uncertainty!(m, s::AutoRegressive, season, method)` pattern in `src/Engines/sddp/build.jl` lines 459-560 for STCHP state creation, AR constraints, inflow coupling, and InflowNonNegativity branching
- Use `__kind_factory!` for seamless JSONC resolution (no registration needed -- just having the type in the module is sufficient)
- Use `CompositeException` accumulation -- constructors return `nothing` on failure
- File pair convention: `vectorautoregressive.jl` (constructors, methods) + `vectorautoregressive-validators.jl` (schemas, validators)
- LP structure tests: use `SDDP.LinearPolicyGraph` with `Ref{JuMP.Model}` capture to verify constraints (see epic-06 learnings)

### Pitfalls to Avoid

- **STCHP indexing**: The existing `AutoRegressive` uses a flat STCHP index where element `n` starts at `index_t[n]` and its lags occupy `index_t[n]` through `index_t[n] + max_lag[n] - 1`. The VAR model should use the same layout for compatibility with memory shift constraints. Since VAR implies all elements share the same max lag, the indexing simplifies to `index_t[n] = (n-1) * max_lag + 1`.
- **Scale normalization in AR constraints**: The existing code normalizes by `(X - mu) / sigma`. The VAR recurrence must apply the same normalization per-element: `(STCHP[i_n].out - mu_s[n]) / sigma_s[n] = sum_l sum_m Phi[n,m] * (STCHP[i_m + l-1].in - mu_{s-l}[m]) / sigma_{s-l}[m] + noise`. This means the coefficient matrix operates in the normalized space.
- **`__build_noise_naive_dict` reuse**: The existing function transforms AR params into Naive noise params by extracting `residual_variance` and setting `kind: "Gaussian"`. The VAR version should reuse this pattern but note that the `marginal_models` dict structure may differ (no `coefficients` key).
- **Do not modify `autoregressive.jl`**: The existing `AutoRegressive` type must remain unchanged for backward compatibility.
- **Test file isolation**: Create a new `test/StochasticProcess/test-vectorautoregressive.jl` file. Never add tests to existing large test files (SIGABRT risk).
- **GLPK is not thread-safe**: Use HiGHS for any LP structure test that involves solver operations.

## Testing Requirements

### Unit Tests

Create `test/StochasticProcess/test-vectorautoregressive.jl`:

1. **Constructor tests**: Valid 2-element VAR(1) and VAR(2) configs construct successfully; invalid configs (wrong matrix dimensions, missing seasons, negative variances) return `nothing` with appropriate errors in `CompositeException`
2. **Size/length tests**: `length(var)` returns number of elements; `size(var)` returns correct tuple
3. **SAA generation tests**: `generate_saa` produces correct dimensions; deterministic with seed; produces different results with different seeds
4. **LP structure tests**: Using `SDDP.LinearPolicyGraph` harness:
   - VAR(1) with 2 elements: verify STCHP has 2 states, verify off-diagonal constraint terms exist
   - VAR(2) with 2 elements: verify STCHP has 4 states, verify memory shift constraints
   - Each `InflowNonNegativity` method: verify INFLOW_SLACK / NOISE_ADJUSTMENT_SLACK creation

### Integration Tests

- End-to-end: construct `ScenariosData` with `VectorAutoRegressive` inflow, build SDDP model, verify model compiles without error
- Use `TEST_FILTER="test-vectorautoregressive"` for targeted execution

### E2E Tests (if applicable)

Not required for this ticket. Integration with full train/simulate is validated in ticket-033.

## Dependencies

- **Blocked By**: ticket-030 (Epic 06 complete -- all InflowNonNegativity methods exist)
- **Blocks**: ticket-032 (Markov chain state transitions will extend this)

## Effort Estimate

**Points**: 4
**Confidence**: Medium (the VAR model follows the same STCHP pattern as AR, but the matrix coefficient constraints add complexity)
