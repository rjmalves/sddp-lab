# Scenarios Configuration

The scenarios configuration defines the stochastic structure of the optimization
problem: the scenario graph (policy graph), inflow uncertainty, load demand,
optional inner load blocks, and optional Markov chain state transitions. It is
specified in `scenarios.jsonc` within the study's `data/` directory.

## Top-Level Structure

```jsonc
{
    // Required keys
    "seed": 42,
    "initial_season": 1,
    "branchings": 10,
    "graph": { ... },
    "inflow": { ... },
    "load": { ... },
    // Optional keys
    "stage_blocks": { ... },
    "markov_chain": { ... }
}
```

### Top-Level Keys

| Key              | Type    | Required | Constraints | Description                                           |
| ---------------- | ------- | -------- | ----------- | ----------------------------------------------------- |
| `seed`           | Integer | Yes      | --          | Random seed for scenario generation                   |
| `initial_season` | Integer | Yes      | > 0         | Starting season index for the stochastic process      |
| `branchings`     | Integer | Yes      | > 0         | Number of scenario branchings (realizations) per node |
| `graph`          | Object  | Yes      | --          | Scenario graph definition (see below)                 |
| `inflow`         | Object  | Yes      | --          | Inflow stochastic process (see below)                 |
| `load`           | Object  | Yes      | --          | Load demand specification (see below)                 |
| `stage_blocks`   | Object  | No       | --          | Per-stage inner load block definitions (see below)    |
| `markov_chain`   | Object  | No       | --          | Markov chain transition matrices (see below)          |

## Graph

The scenario graph defines the nodes (stages) and edges (transitions) of the
SDDP policy graph. It determines the temporal structure of the multistage
problem, including stage durations and discount rates.

### Referencing the Graph File

In `scenarios.jsonc`, the graph is referenced via a `params` block containing a `file` key:

```jsonc
{
  "graph": {
    "params": {
      "file": "graph.jsonc",
    },
  },
}
```

### `graph.jsonc` Format

The graph file contains two arrays: `nodes` and `edges`.

**Nodes:**

| Field            | Type    | Required | Description                               |
| ---------------- | ------- | -------- | ----------------------------------------- |
| `id`             | Integer | Yes      | Unique node identifier                    |
| `stage`          | Integer | Yes      | Stage number (1-indexed)                  |
| `start_datetime` | String  | Yes      | Start date/time of the stage (ISO format) |
| `end_datetime`   | String  | Yes      | End date/time of the stage (ISO format)   |

The duration of each stage (tau, in hours) is computed from the difference
between `end_datetime` and `start_datetime`. This duration is used for
unit conversion between power (MW) and energy (MWh) in the reservoir balance.

**Edges:**

| Field           | Type    | Required | Description                                 |
| --------------- | ------- | -------- | ------------------------------------------- |
| `source`        | Integer | Yes      | Source node id                              |
| `target`        | Integer | Yes      | Target node id                              |
| `probability`   | Real    | Yes      | Transition probability (typically 1.0)      |
| `discount_rate` | Real    | Yes      | Per-stage discount rate (0.0 = no discount) |

### Example

**`graph.jsonc`:**

```jsonc
{
  "nodes": [
    {
      "id": 1,
      "stage": 1,
      "start_datetime": "2024-01-01",
      "end_datetime": "2024-02-01",
    },
    {
      "id": 2,
      "stage": 2,
      "start_datetime": "2024-02-01",
      "end_datetime": "2024-03-01",
    },
    {
      "id": 3,
      "stage": 3,
      "start_datetime": "2024-03-01",
      "end_datetime": "2024-04-01",
    },
  ],
  "edges": [
    { "source": 1, "target": 2, "probability": 1.0, "discount_rate": 0.0 },
    { "source": 2, "target": 3, "probability": 1.0, "discount_rate": 0.0 },
  ],
}
```

!!! note
The root node is automatically identified as the node that is not the target
of any edge.

## Inflow (Stochastic Processes)

The `inflow` section defines the stochastic process that generates inflow
scenarios for the hydro plants. It uses the `kind`/`params` pattern to select
from several stochastic process types.

### Basic Structure

```jsonc
{
  "inflow": {
    "stochastic_process": {
      "kind": "Naive",
      "params": {
        "file": "inflow_scenarios.jsonc",
      },
    },
  },
}
```

### Stochastic Process Kinds

#### `Naive` -- Independent Scenario Sampling

The `Naive` process defines per-hydro, per-season marginal distributions and
inter-variable copulas. Scenarios are sampled independently at each stage using
the specified distributions and copula structure.

**Parameters** (in the referenced JSONC file):

| Key               | Type  | Required | Description                           |
| ----------------- | ----- | -------- | ------------------------------------- |
| `marginal_models` | Array | Yes      | Per-hydro distribution specifications |
| `copulas`         | Array | Yes      | Per-season copula specifications      |

Each entry in `marginal_models`:

| Key             | Type    | Required | Description                            |
| --------------- | ------- | -------- | -------------------------------------- |
| `id`            | Integer | Yes      | Hydro id this model corresponds to     |
| `distributions` | Array   | Yes      | Per-season distribution specifications |

Each distribution entry:

| Key          | Type    | Required | Description                                  |
| ------------ | ------- | -------- | -------------------------------------------- |
| `season`     | Integer | Yes      | Season index (1-indexed)                     |
| `kind`       | String  | Yes      | Distribution name from `Distributions.jl`    |
| `parameters` | Array   | Yes      | Parameter vector in `Distributions.jl` order |

Each copula entry:

| Key          | Type    | Required | Description                                            |
| ------------ | ------- | -------- | ------------------------------------------------------ |
| `season`     | Integer | Yes      | Season index                                           |
| `kind`       | String  | Yes      | Copula name from `Copulas.jl` (e.g., `GaussianCopula`) |
| `parameters` | Array   | Yes      | Copula parameters (matrix as array of row arrays)      |

**Example** (`inflow_scenarios.jsonc`):

```jsonc
{
  "marginal_models": [
    {
      "id": 1,
      "distributions": [
        { "season": 1, "kind": "LogNormal", "parameters": [3.6, 0.48] },
        { "season": 2, "kind": "LogNormal", "parameters": [3.6, 0.48] },
      ],
    },
  ],
  "copulas": [
    { "season": 1, "kind": "GaussianCopula", "parameters": [[1.0]] },
    { "season": 2, "kind": "GaussianCopula", "parameters": [[1.0]] },
  ],
}
```

!!! note
For a single hydro, the copula correlation matrix is `[[1.0]]` (1x1 identity).
For multiple hydros, the matrix size matches the number of `marginal_models`.

#### `AutoRegressive` -- PAR(p) Process

The `AutoRegressive` process implements a periodic autoregressive model of
order p. Each hydro has its own AR model with season-dependent coefficients,
and the noise term uses the same Naive-style marginal/copula structure.

**Parameters:**

| Key               | Type  | Required | Description                             |
| ----------------- | ----- | -------- | --------------------------------------- |
| `marginal_models` | Array | Yes      | Per-hydro AR model specifications       |
| `copulas`         | Array | Yes      | Per-season copula for noise correlation |

Each entry in `marginal_models`:

| Key              | Type         | Required | Description                         |
| ---------------- | ------------ | -------- | ----------------------------------- |
| `id`             | Integer      | Yes      | Hydro id (> 0)                      |
| `initial_values` | Array[Float] | Yes      | Initial lag values for the AR model |
| `models`         | Array        | Yes      | Per-season AR parameter sets        |

Each entry in `models`:

| Key                 | Type         | Required | Constraints | Description                                    |
| ------------------- | ------------ | -------- | ----------- | ---------------------------------------------- |
| `season`            | Integer      | Yes      | > 0         | Season index                                   |
| `coefficients`      | Array[Float] | Yes      | --          | AR coefficients (phi_1, ..., phi_p)            |
| `residual_variance` | Float        | Yes      | > 0         | Variance of the noise term                     |
| `scale_parameters`  | Array[Float] | Yes      | --          | Scale parameters [mean, std] for normalization |

The AR recurrence in normalized space is:

```
(X_t - mu_s) / sigma_s = sum_{l=1}^{p} phi_{s,l} * (X_{t-l} - mu_{s-l}) / sigma_{s-l} + epsilon_t
```

where `scale_parameters = [mu_s, sigma_s]` and `epsilon_t` is drawn from the
noise model defined by the copulas and residual variances.

**Example:**

```jsonc
{
  "inflow": {
    "stochastic_process": {
      "kind": "AutoRegressive",
      "params": {
        "marginal_models": [
          {
            "id": 1,
            "initial_values": [50.0],
            "models": [
              {
                "season": 1,
                "coefficients": [0.7],
                "residual_variance": 100.0,
                "scale_parameters": [50.0, 20.0],
              },
              {
                "season": 2,
                "coefficients": [0.7],
                "residual_variance": 80.0,
                "scale_parameters": [40.0, 15.0],
              },
            ],
          },
        ],
        "copulas": [
          { "season": 1, "kind": "GaussianCopula", "parameters": [[1.0]] },
          { "season": 2, "kind": "GaussianCopula", "parameters": [[1.0]] },
        ],
      },
    },
  },
}
```

!!! note
The length of `initial_values` must match the maximum lag order across all
seasons. If the model has a single season entry, it applies to all seasons
(simple AR). If it has multiple entries, it is a periodic AR (PAR).

#### `VectorAutoRegressive` -- VAR(p) Process

The `VectorAutoRegressive` process generalizes the AR model to the multivariate
case. All hydro plants share coefficient matrices that capture cross-correlations,
while each plant retains its own scale parameters.

**Parameters:**

| Key                    | Type  | Required | Description                                  |
| ---------------------- | ----- | -------- | -------------------------------------------- |
| `marginal_models`      | Array | Yes      | Per-hydro model specs (same structure as AR) |
| `copulas`              | Array | Yes      | Per-season copula for noise correlation      |
| `coefficient_matrices` | Array | Yes      | Per-season, per-lag coefficient matrices     |

Each entry in `marginal_models`:

| Key              | Type         | Required | Description                                                             |
| ---------------- | ------------ | -------- | ----------------------------------------------------------------------- |
| `id`             | Integer      | Yes      | Hydro id (> 0)                                                          |
| `initial_values` | Array[Float] | Yes      | Initial lag values (length = max lag)                                   |
| `models`         | Array        | Yes      | Per-season specs with `season`, `residual_variance`, `scale_parameters` |

Each season model in `models`:

| Key                 | Type         | Required | Constraints       | Description                   |
| ------------------- | ------------ | -------- | ----------------- | ----------------------------- |
| `season`            | Integer      | Yes      | > 0               | Season index                  |
| `residual_variance` | Float        | Yes      | > 0               | Noise variance                |
| `scale_parameters`  | Array[Float] | Yes      | Length 2, std > 0 | [mean, std] for normalization |

Each entry in `coefficient_matrices`:

| Key      | Type    | Required | Constraints | Description                          |
| -------- | ------- | -------- | ----------- | ------------------------------------ |
| `season` | Integer | Yes      | > 0         | Season index                         |
| `lag`    | Integer | Yes      | > 0         | Lag index (1, 2, ..., p)             |
| `matrix` | Array   | Yes      | N x N       | Coefficient matrix (rows of columns) |

The matrix is N x N where N is the number of marginal models (hydros). It is
specified as an array of row arrays.

### Constraints

- Coefficient matrices must be provided for all combinations of seasons and
  lags 1 through max_lag.
- All seasons must have the same max lag.
- `initial_values` length must equal the max lag.
- The matrix in each `coefficient_matrices` entry must be square and match the
  number of marginal models.

**Example** (2 hydros, 1 season, lag 1):

```jsonc
{
  "inflow": {
    "stochastic_process": {
      "kind": "VectorAutoRegressive",
      "params": {
        "marginal_models": [
          {
            "id": 1,
            "initial_values": [50.0],
            "models": [
              {
                "season": 1,
                "residual_variance": 100.0,
                "scale_parameters": [50.0, 20.0],
              },
            ],
          },
          {
            "id": 2,
            "initial_values": [30.0],
            "models": [
              {
                "season": 1,
                "residual_variance": 80.0,
                "scale_parameters": [30.0, 10.0],
              },
            ],
          },
        ],
        "copulas": [
          {
            "season": 1,
            "kind": "GaussianCopula",
            "parameters": [
              [1.0, 0.5],
              [0.5, 1.0],
            ],
          },
        ],
        "coefficient_matrices": [
          {
            "season": 1,
            "lag": 1,
            "matrix": [
              [0.7, 0.1],
              [0.2, 0.6],
            ],
          },
        ],
      },
    },
  },
}
```

### Per-State Stochastic Processes (Markov Mode)

When using a Markov chain (see below), the `stochastic_process` key holds a
dictionary of state-specific processes instead of a single `kind`/`params` block.
The keys are string integers matching the Markov state indices:

```jsonc
{
    "inflow": {
        "stochastic_process": {
            "1": {
                "kind": "AutoRegressive",
                "params": { ... }
            },
            "2": {
                "kind": "AutoRegressive",
                "params": { ... }
            }
        }
    }
}
```

The number of entries must match the number of Markov states, and the keys
must be exactly `"1"`, `"2"`, ..., `"N"`.

## Load

The `load` section defines the demand at each bus for each graph node. It uses
the `kind`/`params` pattern.

### `DeterministicLoad`

The standard load format specifies deterministic load values per bus per graph node.

**Inline format** (in `scenarios.jsonc`):

```jsonc
{
  "load": {
    "kind": "DeterministicLoad",
    "params": {
      "values": [
        { "bus_id": 1, "node_id": 1, "value": 75.0 },
        { "bus_id": 1, "node_id": 2, "value": 75.0 },
        { "bus_id": 1, "node_id": 3, "value": 80.0 },
      ],
    },
  },
}
```

**CSV file format** (referenced via `"file"` key):

```jsonc
{
  "load": {
    "kind": "DeterministicLoad",
    "params": {
      "file": "load.csv",
    },
  },
}
```

**`load.csv` columns:**

| Column    | Type    | Required | Constraints | Description           |
| --------- | ------- | -------- | ----------- | --------------------- |
| `bus_id`  | Integer | Yes      | > 0         | Bus identifier        |
| `node_id` | Integer | Yes      | > 0         | Graph node identifier |
| `value`   | Real    | Yes      | --          | Load demand (MW)      |

Each `(bus_id, node_id)` pair must be unique. A `node_id` must reference a valid
node in the graph. Missing pairs default to 0.0 MW with a warning.

### Block-Specific Load

When using inner load blocks, each load entry can include a `block` field that
associates the value with a specific block name:

```jsonc
{
  "load": {
    "kind": "DeterministicLoad",
    "params": {
      "values": [
        { "bus_id": 1, "node_id": 2, "value": 90.0, "block": "peak" },
        { "bus_id": 1, "node_id": 2, "value": 60.0, "block": "offpeak" },
      ],
    },
  },
}
```

Each `(bus_id, node_id, block)` triple must be unique.

## Per-Stage Blocks (Optional)

The `stage_blocks` key defines inner load blocks on a per-stage basis. This
allows modeling of load duration curves or chronological dispatch within each
stage, with different block configurations per stage (e.g., different durations
for months of varying length).

### Structure

Each key in `stage_blocks` is a string-integer stage index. The value is a
block configuration object with `mode` and `definitions`:

```jsonc
{
  "stage_blocks": {
    "1": {
      "mode": "parallel",
      "definitions": [
        { "name": "peak", "duration_hours": 124.0 },
        { "name": "shoulder", "duration_hours": 248.0 },
        { "name": "offpeak", "duration_hours": 372.0 },
      ],
    },
    "2": {
      "mode": "parallel",
      "definitions": [
        { "name": "peak", "duration_hours": 116.0 },
        { "name": "shoulder", "duration_hours": 232.0 },
        { "name": "offpeak", "duration_hours": 348.0 },
      ],
    },
  },
}
```

### Per-Stage Block Configuration Keys

| Key           | Type   | Required | Valid Values                      | Description            |
| ------------- | ------ | -------- | --------------------------------- | ---------------------- |
| `mode`        | String | Yes      | `"parallel"` or `"chronological"` | Block aggregation mode |
| `definitions` | Array  | Yes      | Non-empty                         | Block specifications   |

Each block definition:

| Key              | Type   | Required | Constraints | Description                   |
| ---------------- | ------ | -------- | ----------- | ----------------------------- |
| `name`           | String | Yes      | Unique      | Block identifier              |
| `duration_hours` | Real   | Yes      | > 0         | Duration of the block (hours) |

### Block Duration Validation

The sum of `duration_hours` across all block definitions for a given stage must
equal the stage duration derived from the graph node's `start_datetime` and
`end_datetime`. For example, if a stage spans from `2024-01-01` to `2024-02-01`
(744 hours), the block durations must sum to exactly 744.0.

Stages not present in `stage_blocks` use a single implicit block spanning the
full stage duration.

### Block Modes

- **`parallel`**: A single water balance per hydro across all blocks. Block
  contributions are weighted by `w_k = duration_hours_k / sum(duration_hours)`.
  This is the load-duration-curve approximation.

- **`chronological`**: Separate water balances per block with intermediate storage
  variables. This models within-stage chronological dispatch more accurately but
  increases problem size.

!!! note
When `stage_blocks` is omitted entirely, each stage uses a single implicit
block spanning the full stage duration (determined from the graph node's
`start_datetime` and `end_datetime`).

### Deprecated: Global `blocks` Key

The legacy `blocks` key (a single block configuration applied uniformly to all
stages) is still accepted but deprecated and will emit a warning. Use
`stage_blocks` with per-stage keys instead.

```jsonc
// DEPRECATED -- use stage_blocks instead
{
  "blocks": {
    "mode": "parallel",
    "definitions": [
      { "name": "peak", "duration_hours": 6.0 },
      { "name": "offpeak", "duration_hours": 18.0 },
    ],
  },
}
```

You cannot specify both `blocks` and `stage_blocks` simultaneously.

## Markov Chain (Optional)

The `markov_chain` key defines a discrete Markov chain that indexes state-dependent
stochastic processes. This enables modeling regime-switching behavior (e.g.,
wet/dry hydrological regimes).

### Structure

```jsonc
{
  "markov_chain": {
    "transition_matrices": [
      // Matrix 1: root -> states (1 x N)
      [[0.5, 0.5]],
      // Matrix 2: states -> states (N x N)
      [
        [0.7, 0.3],
        [0.4, 0.6],
      ],
      // Matrix 3: states -> states (N x N)
      [
        [0.7, 0.3],
        [0.4, 0.6],
      ],
    ],
  },
}
```

### Keys

| Key                   | Type  | Required | Description                                    |
| --------------------- | ----- | -------- | ---------------------------------------------- |
| `transition_matrices` | Array | Yes      | Sequence of transition matrices, one per stage |

### Transition Matrix Rules

1. The **first** matrix must have exactly 1 row (it transitions from the root
   node to the initial Markov states). Its number of columns N defines the
   number of Markov states.

2. All **subsequent** matrices must be square (N x N), where N matches the
   number of columns from the first matrix.

3. The number of rows in matrix `i+1` must equal the number of columns in
   matrix `i`.

4. All entries must be non-negative.

5. Each row must sum to 1.0 (within tolerance 1e-6).

### Integration with Stochastic Processes

When a Markov chain is present, the `inflow.stochastic_process` must use the
per-state dictionary format (see "Per-State Stochastic Processes" above), with
exactly N entries matching the N Markov states.

**Example** (2 states, 3 stages):

```jsonc
{
    "seed": 42,
    "initial_season": 1,
    "branchings": 10,
    "graph": {
        "params": { "file": "graph.jsonc" }
    },
    "inflow": {
        "stochastic_process": {
            "1": {
                "kind": "AutoRegressive",
                "params": { ... }
            },
            "2": {
                "kind": "AutoRegressive",
                "params": { ... }
            }
        }
    },
    "load": {
        "kind": "DeterministicLoad",
        "params": { "file": "load.csv" }
    },
    "markov_chain": {
        "transition_matrices": [
            [[0.5, 0.5]],
            [[0.7, 0.3], [0.4, 0.6]],
            [[0.7, 0.3], [0.4, 0.6]]
        ]
    }
}
```

## Complete Example

A complete `scenarios.jsonc` for a simple study:

```jsonc
{
  "seed": 42,
  "initial_season": 1,
  "branchings": 10,
  "graph": {
    "params": {
      "file": "graph.jsonc",
    },
  },
  "inflow": {
    "stochastic_process": {
      "kind": "Naive",
      "params": {
        "file": "inflow_scenarios.jsonc",
      },
    },
  },
  "load": {
    "kind": "DeterministicLoad",
    "params": {
      "file": "load.csv",
    },
  },
}
```
