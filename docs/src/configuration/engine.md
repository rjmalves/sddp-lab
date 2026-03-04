# Engine Configuration

The engine configuration controls the SDDP optimization algorithm: convergence
criteria, risk measures, parallelization, sampling, duality handling, forward
pass strategy, cut management, scaling, solver selection, diagnostics, debugging,
validation, and inflow non-negativity modeling. It is defined in the `engine`
section of `main.jsonc`.

## Top-Level Structure

The engine uses the `kind`/`params` pattern. Currently, the only supported
engine kind is `SDDPEngine`.

```jsonc
{
    "engine": {
        "kind": "SDDPEngine",
        "params": {
            "policy": { ... },          // Required
            "simulation": { ... },      // Required
            "solver": { ... },          // Optional (default: HiGHS)
            "diagnostics": { ... },     // Optional
            "modeling": { ... },        // Optional (inflow non-negativity)
            "validation": { ... },      // Optional
            "debug": { ... }            // Optional
        }
    }
}
```

### Engine `params` Keys

| Key           | Type   | Required | Default                         | Description                   |
| ------------- | ------ | -------- | ------------------------------- | ----------------------------- |
| `policy`      | Object | Yes      | --                              | Training policy configuration |
| `simulation`  | Object | Yes      | --                              | Simulation configuration      |
| `solver`      | Object | No       | HiGHS with no attributes        | LP/MIP solver                 |
| `diagnostics` | Object | No       | Report off, warn=1e6, halt=1e10 | Numerical diagnostics         |
| `modeling`    | Object | No       | `InflowNone`                    | Modeling options              |
| `validation`  | Object | No       | No validation                   | Out-of-sample validation      |
| `debug`       | Object | No       | All disabled                    | Debug output options          |

## Policy Configuration

The `policy` section controls the SDDP training algorithm.

```jsonc
{
    "policy": {
        "convergence": { ... },       // Required
        "risk_measure": { ... },      // Required
        "parallel_scheme": { ... },   // Required
        "sampling_scheme": { ... },   // Optional
        "duality_handler": { ... },   // Optional
        "forward_pass": { ... },      // Optional
        "cut_type": { ... },          // Optional
        "scaling": { ... },           // Optional
        "logging": { ... }            // Optional
    }
}
```

### Policy Keys

| Key               | Type   | Required | Default                      | Description                           |
| ----------------- | ------ | -------- | ---------------------------- | ------------------------------------- |
| `convergence`     | Object | Yes      | --                           | Convergence and stopping rules        |
| `risk_measure`    | Object | Yes      | --                           | Risk measure for the Bellman operator |
| `parallel_scheme` | Object | Yes      | --                           | Parallelization strategy              |
| `sampling_scheme` | Object | No       | `DefaultSampling`            | Scenario sampling scheme              |
| `duality_handler` | Object | No       | `DefaultDuality`             | Duality handler for cut generation    |
| `forward_pass`    | Object | No       | `DefaultForwardPassStrategy` | Forward pass strategy                 |
| `cut_type`        | Object | No       | `SingleCut`                  | Cut aggregation type                  |
| `scaling`         | Object | No       | `NoScaling`                  | Coefficient scaling mode              |
| `logging`         | Object | No       | Default log config           | Training log output                   |

## Convergence

The `convergence` section specifies iteration bounds and stopping criteria.

```jsonc
{
    "convergence": {
        "min_iterations": 10,
        "max_iterations": 200,
        "stopping_criteria": { ... }
    }
}
```

### Convergence Keys

| Key                 | Type            | Required | Constraints              | Description                 |
| ------------------- | --------------- | -------- | ------------------------ | --------------------------- |
| `min_iterations`    | Integer         | Yes      | > 0                      | Minimum training iterations |
| `max_iterations`    | Integer         | Yes      | > 0, >= `min_iterations` | Maximum training iterations |
| `stopping_criteria` | Object or Array | Yes      | --                       | Stopping rule(s)            |

The `stopping_criteria` key accepts either a single `kind`/`params` object or an
array of them. When an array is provided, all criteria are evaluated and the
algorithm stops when any one of them is satisfied.

**Single criterion:**

```jsonc
{
  "stopping_criteria": {
    "kind": "IterationLimit",
    "params": { "num_iterations": 100 },
  },
}
```

**Multiple criteria (array):**

```jsonc
{
  "stopping_criteria": [
    { "kind": "IterationLimit", "params": { "num_iterations": 200 } },
    { "kind": "TimeLimit", "params": { "time_seconds": 3600 } },
  ],
}
```

### Stopping Criteria Kinds

#### `IterationLimit`

Stop after a fixed number of iterations.

| Parameter        | Type    | Required | Constraints | Description                  |
| ---------------- | ------- | -------- | ----------- | ---------------------------- |
| `num_iterations` | Integer | Yes      | > 0         | Maximum number of iterations |

```jsonc
{ "kind": "IterationLimit", "params": { "num_iterations": 100 } }
```

#### `TimeLimit`

Stop after a time limit.

| Parameter      | Type    | Required | Constraints | Description           |
| -------------- | ------- | -------- | ----------- | --------------------- |
| `time_seconds` | Integer | Yes      | > 0         | Time limit in seconds |

```jsonc
{ "kind": "TimeLimit", "params": { "time_seconds": 3600 } }
```

#### `LowerBoundStability`

Stop when the lower bound has not improved by more than `threshold` (relative)
over the last `num_iterations` iterations (maps to `SDDP.BoundStalling`).

| Parameter        | Type    | Required | Constraints | Description                        |
| ---------------- | ------- | -------- | ----------- | ---------------------------------- |
| `threshold`      | Real    | Yes      | 0 < x < 1   | Relative improvement threshold     |
| `num_iterations` | Integer | Yes      | > 0         | Number of iterations to check over |

```jsonc
{
  "kind": "LowerBoundStability",
  "params": { "threshold": 0.01, "num_iterations": 50 },
}
```

#### `Statistical`

Periodically run simulations and stop when the upper bound confidence interval
overlaps the lower bound.

| Parameter          | Type    | Required | Constraints | Description                       |
| ------------------ | ------- | -------- | ----------- | --------------------------------- |
| `num_replications` | Integer | Yes      | > 0         | Number of simulation replications |
| `iteration_period` | Integer | Yes      | > 0         | Check every N iterations          |
| `z_score`          | Real    | Yes      | > 0         | Z-score for confidence interval   |

```jsonc
{
  "kind": "Statistical",
  "params": {
    "num_replications": 100,
    "iteration_period": 10,
    "z_score": 1.96,
  },
}
```

#### `SimulationStopping`

Stop based on simulation results evaluated periodically (maps to
`SDDP.SimulationStoppingRule`).

| Parameter      | Type    | Required | Constraints | Description            |
| -------------- | ------- | -------- | ----------- | ---------------------- |
| `replications` | Integer | Yes      | > 0         | Number of replications |
| `period`       | Integer | Yes      | > 0         | Evaluation period      |

```jsonc
{ "kind": "SimulationStopping", "params": { "replications": 100, "period": 5 } }
```

#### `FirstStageStopping`

Stop when the first-stage solution stabilizes (maps to
`SDDP.FirstStageStoppingRule`).

| Parameter    | Type    | Required | Constraints | Description                        |
| ------------ | ------- | -------- | ----------- | ---------------------------------- |
| `atol`       | Real    | Yes      | > 0         | Absolute tolerance                 |
| `iterations` | Integer | Yes      | > 0         | Number of stable iterations needed |

```jsonc
{ "kind": "FirstStageStopping", "params": { "atol": 0.01, "iterations": 10 } }
```

#### `StoppingChain`

Combine multiple stopping rules into a chain. The chain stops when all inner
rules are simultaneously satisfied (logical AND).

| Parameter | Type  | Required | Constraints | Description                |
| --------- | ----- | -------- | ----------- | -------------------------- |
| `rules`   | Array | Yes      | Non-empty   | Array of stopping criteria |

```jsonc
{
  "kind": "StoppingChain",
  "params": {
    "rules": [
      { "kind": "IterationLimit", "params": { "num_iterations": 50 } },
      {
        "kind": "LowerBoundStability",
        "params": { "threshold": 0.01, "num_iterations": 20 },
      },
    ],
  },
}
```

!!! note
The difference between an array of stopping criteria in `stopping_criteria`
(OR logic -- stop when **any** is satisfied) and `StoppingChain` (AND logic
-- stop when **all** are satisfied).

## Risk Measures

The `risk_measure` section defines the risk measure applied to the Bellman
operator at each stage. It uses the `kind`/`params` pattern.

### `Expectation`

Risk-neutral expected value. No parameters needed.

```jsonc
{ "kind": "Expectation", "params": {} }
```

### `WorstCase`

Worst-case (minimax) risk measure. No parameters needed.

```jsonc
{ "kind": "WorstCase", "params": {} }
```

### `AVaR`

Average Value-at-Risk (also known as CVaR in some references). Maps to
`SDDP.AVaR(alpha)`.

| Parameter | Type | Required | Constraints | Description      |
| --------- | ---- | -------- | ----------- | ---------------- |
| `alpha`   | Real | Yes      | 0 <= x <= 1 | Confidence level |

When `alpha = 1.0`, this is equivalent to `Expectation`. When `alpha = 0.0`,
this is equivalent to `WorstCase`.

```jsonc
{ "kind": "AVaR", "params": { "alpha": 0.5 } }
```

### `CVaR`

Convex combination of expectation and AVaR (maps to `SDDP.EAVaR`). This is
the time-consistent risk measure formulation:

```
rho(Z) = (1 - lambda) * E[Z] + lambda * AVaR_alpha(Z)
```

| Parameter | Type | Required | Constraints | Description                    |
| --------- | ---- | -------- | ----------- | ------------------------------ |
| `alpha`   | Real | Yes      | 0 <= x <= 1 | AVaR confidence level          |
| `lambda`  | Real | Yes      | 0 <= x <= 1 | Weight on AVaR (risk aversion) |

When `lambda = 0.0`, this is pure expectation. When `lambda = 1.0`, this is
pure AVaR.

```jsonc
{ "kind": "CVaR", "params": { "alpha": 0.2, "lambda": 0.9 } }
```

!!! warning
The internal mapping to SDDP.jl uses `SDDP.EAVaR(beta=alpha, lambda=1-lambda)`.
The SDDPlab `lambda` parameter represents the weight on the risk-averse
component, while SDDP.jl's `lambda` parameter represents the weight on the
expectation component.

### `Entropic`

Entropic risk measure (exponential risk measure).

| Parameter | Type | Required | Constraints | Description             |
| --------- | ---- | -------- | ----------- | ----------------------- |
| `theta`   | Real | Yes      | > 0         | Risk aversion parameter |

```jsonc
{ "kind": "Entropic", "params": { "theta": 0.1 } }
```

### `WassersteinRM`

Wasserstein distributionally robust risk measure.

| Parameter | Type | Required | Constraints | Description          |
| --------- | ---- | -------- | ----------- | -------------------- |
| `alpha`   | Real | Yes      | 0 < x < 1   | Robustness parameter |

```jsonc
{ "kind": "WassersteinRM", "params": { "alpha": 0.5 } }
```

!!! note
`WassersteinRM` requires an LP solver to be available. It will automatically
use HiGHS or GLPK if installed.

### `ModifiedChiSquared`

Modified chi-squared distributionally robust risk measure.

| Parameter     | Type | Required | Constraints | Description                            |
| ------------- | ---- | -------- | ----------- | -------------------------------------- |
| `radius`      | Real | Yes      | > 0         | Ambiguity set radius                   |
| `minimum_std` | Real | Yes      | 0 < x < 1   | Minimum standard deviation for scaling |

```jsonc
{
  "kind": "ModifiedChiSquared",
  "params": { "radius": 0.1, "minimum_std": 0.01 },
}
```

### `ConvexCombination`

Convex combination of multiple risk measures with specified weights.

| Parameter  | Type  | Required | Constraints                 | Description            |
| ---------- | ----- | -------- | --------------------------- | ---------------------- |
| `measures` | Array | Yes      | Non-empty, weights sum to 1 | Weighted risk measures |

Each entry in the `measures` array:

| Key            | Type   | Required | Constraints     | Description             |
| -------------- | ------ | -------- | --------------- | ----------------------- |
| `weight`       | Real   | Yes      | 0 < w <= 1      | Weight for this measure |
| `risk_measure` | Object | Yes      | `kind`/`params` | Inner risk measure      |

```jsonc
{
  "kind": "ConvexCombination",
  "params": {
    "measures": [
      {
        "weight": 0.5,
        "risk_measure": { "kind": "Expectation", "params": {} },
      },
      {
        "weight": 0.5,
        "risk_measure": { "kind": "AVaR", "params": { "alpha": 0.1 } },
      },
    ],
  },
}
```

## Parallel Schemes

The `parallel_scheme` section controls how SDDP iterations are parallelized.

### `Serial`

Single-threaded execution. No parameters needed.

```jsonc
{ "kind": "Serial", "params": {} }
```

### `Threaded`

Multi-threaded execution using Julia threads. Requires starting Julia with
`--threads N`.

```jsonc
{ "kind": "Threaded", "params": {} }
```

!!! warning
When using `Threaded`, the solver must be thread-safe. GLPK is NOT
thread-safe. Use HiGHS or another thread-safe solver.

### `Asynchronous`

Distributed execution using Julia's `Distributed` module. Requires launching
workers with `julia -p N` or `Distributed.addprocs(N)`.

```jsonc
{ "kind": "Asynchronous", "params": {} }
```

## Sampling Schemes

The `sampling_scheme` section controls how scenarios are sampled during the
forward pass. This key is optional; the default is `DefaultSampling`.

### `DefaultSampling`

SDDP.jl's default in-sample Monte Carlo sampling. No parameters needed. When
used without explicit parameters, the max depth is set to the graph size and
dummy leaf termination is disabled.

```jsonc
{ "kind": "DefaultSampling", "params": {} }
```

### `InSampleMC`

In-sample Monte Carlo sampling with explicit control over depth and termination.

| Parameter                 | Type    | Required | Constraints | Description                         |
| ------------------------- | ------- | -------- | ----------- | ----------------------------------- |
| `max_depth`               | Integer | Yes      | > 0         | Maximum depth of sampled paths      |
| `terminate_on_dummy_leaf` | Bool    | Yes      | --          | Whether to stop at dummy leaf nodes |

```jsonc
{
  "kind": "InSampleMC",
  "params": { "max_depth": 10, "terminate_on_dummy_leaf": false },
}
```

### `PSRSampling`

PSR sampling scheme for scenario generation.

| Parameter     | Type    | Required | Constraints | Description       |
| ------------- | ------- | -------- | ----------- | ----------------- |
| `num_samples` | Integer | Yes      | > 0         | Number of samples |

```jsonc
{ "kind": "PSRSampling", "params": { "num_samples": 100 } }
```

## Duality Handlers

The `duality_handler` section controls how dual information is extracted from
subproblems for cut generation. This key is optional; the default is
`DefaultDuality`.

### `DefaultDuality`

SDDP.jl's default duality handler. No parameters needed.

```jsonc
{ "kind": "DefaultDuality", "params": {} }
```

### `ContinuousConicDualityHandler`

Continuous conic duality for LP subproblems.

```jsonc
{ "kind": "ContinuousConicDualityHandler", "params": {} }
```

### `StrengthenedConicDualityHandler`

Strengthened conic duality for tighter cuts.

```jsonc
{ "kind": "StrengthenedConicDualityHandler", "params": {} }
```

### `LagrangianDualityHandler`

Lagrangian duality for problems with integer variables.

```jsonc
{ "kind": "LagrangianDualityHandler", "params": {} }
```

### `BanditDualityHandler`

Multi-armed bandit approach that selects among multiple duality handlers
adaptively during training.

| Parameter  | Type  | Required | Constraints  | Description                      |
| ---------- | ----- | -------- | ------------ | -------------------------------- |
| `handlers` | Array | Yes      | >= 2 entries | Array of duality handler objects |

```jsonc
{
  "kind": "BanditDualityHandler",
  "params": {
    "handlers": [
      { "kind": "ContinuousConicDualityHandler", "params": {} },
      { "kind": "StrengthenedConicDualityHandler", "params": {} },
    ],
  },
}
```

## Forward Pass Strategies

The `forward_pass` section controls the forward pass behavior during training.
This key is optional; the default is `DefaultForwardPassStrategy`.

### `DefaultForwardPassStrategy`

SDDP.jl's default forward pass. No parameters needed.

```jsonc
{ "kind": "DefaultForwardPassStrategy", "params": {} }
```

### `RevisitingForwardPassStrategy`

Revisits previously computed solutions periodically.

| Parameter | Type    | Required | Constraints | Description                    |
| --------- | ------- | -------- | ----------- | ------------------------------ |
| `period`  | Integer | Yes      | > 0         | Revisiting period (iterations) |

```jsonc
{ "kind": "RevisitingForwardPassStrategy", "params": { "period": 5 } }
```

### `RiskAdjustedForwardPassStrategy`

Risk-adjusted forward pass that resamples using a risk measure. Uses
`SDDP.AVaR(0.5)` and resampling probability 0.5 by default (hardcoded).

```jsonc
{ "kind": "RiskAdjustedForwardPassStrategy", "params": {} }
```

### `RegularizedForwardPassStrategy`

Regularized forward pass (SDDP-REG) with a proximal term penalty.

| Parameter | Type | Required | Constraints | Description              |
| --------- | ---- | -------- | ----------- | ------------------------ |
| `rho`     | Real | Yes      | > 0         | Regularization parameter |

```jsonc
{ "kind": "RegularizedForwardPassStrategy", "params": { "rho": 0.01 } }
```

## Cut Types

The `cut_type` section selects between single-cut and multi-cut aggregation.
This key is optional; the default is `SingleCut`.

### `SingleCut`

Aggregate all scenario cuts into a single expected-value cut per stage. This
is the classic SDDP formulation.

```jsonc
{ "kind": "SingleCut", "params": {} }
```

### `MultiCut`

Maintain one cut per scenario per stage. Potentially faster convergence but
larger subproblems.

```jsonc
{ "kind": "MultiCut", "params": {} }
```

## Scaling

The `scaling` section controls automatic coefficient scaling in the SDDP
subproblems. This key is optional; the default is `NoScaling`.

### `NoScaling`

No scaling applied. Subproblem coefficients are used as-is.

```jsonc
{ "kind": "NoScaling", "params": {} }
```

### `AutoScaling`

Automatic scaling of objective and constraint coefficients to improve
numerical conditioning.

```jsonc
{ "kind": "AutoScaling", "params": {} }
```

## Logging

The `logging` section controls training progress output. All keys are optional.

```jsonc
{
  "logging": {
    "log_file": "training.log",
    "log_frequency": 10,
    "log_every_iteration": false,
    "print_level": 1,
  },
}
```

### Logging Keys

| Key                   | Type    | Required | Default | Constraints | Description                                  |
| --------------------- | ------- | -------- | ------- | ----------- | -------------------------------------------- |
| `log_file`            | String  | No       | `""`    | --          | Path to write training log (empty = no file) |
| `log_frequency`       | Integer | No       | `1`     | > 0         | Print every N iterations                     |
| `log_every_iteration` | Bool    | No       | `false` | --          | Print every iteration (overrides frequency)  |
| `print_level`         | Integer | No       | `1`     | 0, 1, or 2  | Verbosity (0=silent, 1=normal, 2=verbose)    |

## Simulation Configuration

The `simulation` section configures the post-training Monte Carlo simulation.

```jsonc
{
  "simulation": {
    "num_simulated_series": 100,
    "parallel_scheme": {
      "kind": "Serial",
      "params": {},
    },
  },
}
```

### Simulation Keys

| Key                    | Type    | Required | Default           | Constraints     | Description                       |
| ---------------------- | ------- | -------- | ----------------- | --------------- | --------------------------------- |
| `num_simulated_series` | Integer | Yes      | --                | > 0             | Number of Monte Carlo simulations |
| `parallel_scheme`      | Object  | Yes      | --                | `kind`/`params` | Parallelization for simulation    |
| `sampling_scheme`      | Object  | No       | `DefaultSampling` | `kind`/`params` | Sampling scheme for simulation    |

The `parallel_scheme` and `sampling_scheme` use the same kinds as in the
policy section.

## Solver Configuration

The `solver` section selects and configures the LP/MIP solver for subproblems.
This section is optional; the default is HiGHS with no custom attributes.

```jsonc
{
  "solver": {
    "name": "HiGHS",
    "attributes": {
      "output_flag": false,
      "time_limit": 60.0,
    },
  },
}
```

### Solver Keys

| Key          | Type   | Required | Default   | Constraints | Description                         |
| ------------ | ------ | -------- | --------- | ----------- | ----------------------------------- |
| `name`       | String | Yes      | `"HiGHS"` | Non-empty   | Solver name (must be installed)     |
| `attributes` | Object | No       | `{}`      | --          | Solver-specific attribute overrides |

The `attributes` dictionary is passed directly to the solver optimizer. Keys
and values are solver-specific. Consult the solver documentation for available
options.

Common solver names: `"HiGHS"`, `"GLPK"`, `"Gurobi"`, `"CPLEX"`.

!!! warning
The solver package must be installed in the Julia environment. For example,
to use Gurobi, you need `import Pkg; Pkg.add("Gurobi")` and a valid license.

## Diagnostics Configuration

The `diagnostics` section enables numerical health checks on the subproblems.
This section is optional.

```jsonc
{
  "diagnostics": {
    "run_numerical_report": true,
    "warn_threshold": 1e6,
    "halt_threshold": 1e10,
  },
}
```

### Diagnostics Keys

| Key                    | Type | Required | Default | Constraints              | Description                                 |
| ---------------------- | ---- | -------- | ------- | ------------------------ | ------------------------------------------- |
| `run_numerical_report` | Bool | Yes      | `false` | --                       | Enable numerical diagnostics                |
| `warn_threshold`       | Real | Yes      | `1e6`   | > 0                      | Coefficient magnitude that triggers warning |
| `halt_threshold`       | Real | Yes      | `1e10`  | > 0, >= `warn_threshold` | Coefficient magnitude that halts execution  |

!!! note
`halt_threshold` must be greater than or equal to `warn_threshold`.

## Inflow Non-Negativity Modeling

The `modeling` section (nested under engine `params`) controls how negative
inflows are handled. This is important when stochastic processes generate
negative realizations.

!!! warning
The inflow non-negativity option is nested under a `modeling` key, not
directly under the engine `params`. The correct path is
`params.modeling.inflow_non_negativity`.

```jsonc
{
  "modeling": {
    "inflow_non_negativity": {
      "kind": "InflowPenalty",
      "params": {
        "penalty_cost": 1000.0,
      },
    },
  },
}
```

### Inflow Non-Negativity Kinds

#### `InflowNone`

No inflow non-negativity handling. Negative inflows are passed through as-is.
This is the default.

```jsonc
{ "kind": "InflowNone", "params": {} }
```

#### `InflowPenalty`

Add a penalty variable for negative inflows without truncating them.

| Parameter      | Type | Required | Constraints | Description                                |
| -------------- | ---- | -------- | ----------- | ------------------------------------------ |
| `penalty_cost` | Real | Yes      | > 0         | Cost per unit of negative inflow (\$/unit) |

```jsonc
{ "kind": "InflowPenalty", "params": { "penalty_cost": 1000.0 } }
```

#### `InflowTruncation`

Truncate negative inflows to zero. No parameters needed.

```jsonc
{ "kind": "InflowTruncation", "params": {} }
```

#### `InflowTruncationWithPenalty`

Truncate negative inflows to zero and add a penalty for the truncated amount.

| Parameter      | Type | Required | Constraints | Description                       |
| -------------- | ---- | -------- | ----------- | --------------------------------- |
| `penalty_cost` | Real | Yes      | > 0         | Cost per unit of truncated inflow |

```jsonc
{ "kind": "InflowTruncationWithPenalty", "params": { "penalty_cost": 500.0 } }
```

## Validation Configuration

The `validation` section configures out-of-sample validation runs after
training. When present, the system generates fresh scenarios (with a separate
seed and branching count) and simulates the trained policy to evaluate
out-of-sample performance. This section is optional; when omitted, no
validation is performed.

```jsonc
{
  "validation": {
    "num_simulations": 200,
    "seed": 123,
    "branchings": 20,
    "parallel_scheme": {
      "kind": "Serial",
      "params": {},
    },
  },
}
```

### Validation Keys

| Key               | Type    | Required | Constraints     | Description                                     |
| ----------------- | ------- | -------- | --------------- | ----------------------------------------------- |
| `num_simulations` | Integer | Yes      | > 0             | Number of out-of-sample simulation replications |
| `seed`            | Integer | Yes      | > 0             | Random seed for validation scenarios            |
| `branchings`      | Integer | Yes      | > 0             | Number of branchings for validation tree        |
| `parallel_scheme` | Object  | Yes      | `kind`/`params` | Parallelization for validation                  |

## Debug Configuration

The `debug` section enables writing subproblem files and computing the
deterministic equivalent for diagnostic purposes. This section is optional;
all keys within are also optional with sensible defaults.

```jsonc
{
  "debug": {
    "write_subproblems": true,
    "subproblem_nodes": [1, 2, 3],
    "subproblem_format": "lp",
    "deterministic_equivalent": false,
    "det_equiv_time_limit": 120.0,
  },
}
```

### Debug Keys

| Key                        | Type   | Required | Default | Constraints                 | Description                                |
| -------------------------- | ------ | -------- | ------- | --------------------------- | ------------------------------------------ |
| `write_subproblems`        | Bool   | No       | `false` | --                          | Write subproblem formulations to files     |
| `subproblem_nodes`         | Array  | No       | `[]`    | --                          | Node ids to write (empty = all nodes)      |
| `subproblem_format`        | String | No       | `"mof"` | `"mof"`, `"lp"`, or `"mps"` | Output format for subproblems              |
| `deterministic_equivalent` | Bool   | No       | `false` | --                          | Compute and solve deterministic equivalent |
| `det_equiv_time_limit`     | Real   | No       | `60.0`  | > 0                         | Time limit for det. equiv. solve (seconds) |

## Complete Engine Example

A comprehensive `engine` configuration using many available options:

```jsonc
{
  "engine": {
    "kind": "SDDPEngine",
    "params": {
      "policy": {
        "convergence": {
          "min_iterations": 20,
          "max_iterations": 500,
          "stopping_criteria": [
            {
              "kind": "IterationLimit",
              "params": { "num_iterations": 500 },
            },
            {
              "kind": "TimeLimit",
              "params": { "time_seconds": 3600 },
            },
            {
              "kind": "Statistical",
              "params": {
                "num_replications": 100,
                "iteration_period": 50,
                "z_score": 1.96,
              },
            },
          ],
        },
        "risk_measure": {
          "kind": "CVaR",
          "params": { "alpha": 0.2, "lambda": 0.9 },
        },
        "parallel_scheme": {
          "kind": "Serial",
          "params": {},
        },
        "sampling_scheme": {
          "kind": "InSampleMC",
          "params": { "max_depth": 12, "terminate_on_dummy_leaf": false },
        },
        "duality_handler": {
          "kind": "ContinuousConicDualityHandler",
          "params": {},
        },
        "forward_pass": {
          "kind": "RegularizedForwardPassStrategy",
          "params": { "rho": 0.01 },
        },
        "cut_type": {
          "kind": "MultiCut",
          "params": {},
        },
        "scaling": {
          "kind": "AutoScaling",
          "params": {},
        },
        "logging": {
          "log_file": "training.log",
          "log_frequency": 10,
          "log_every_iteration": false,
          "print_level": 1,
        },
      },
      "simulation": {
        "num_simulated_series": 200,
        "parallel_scheme": {
          "kind": "Serial",
          "params": {},
        },
        "sampling_scheme": {
          "kind": "InSampleMC",
          "params": { "max_depth": 12, "terminate_on_dummy_leaf": false },
        },
      },
      "solver": {
        "name": "HiGHS",
        "attributes": {
          "output_flag": false,
        },
      },
      "diagnostics": {
        "run_numerical_report": true,
        "warn_threshold": 1e6,
        "halt_threshold": 1e10,
      },
      "modeling": {
        "inflow_non_negativity": {
          "kind": "InflowTruncationWithPenalty",
          "params": { "penalty_cost": 500.0 },
        },
      },
      "validation": {
        "num_simulations": 200,
        "seed": 123,
        "branchings": 20,
        "parallel_scheme": {
          "kind": "Serial",
          "params": {},
        },
      },
      "debug": {
        "write_subproblems": false,
        "deterministic_equivalent": false,
      },
    },
  },
}
```
