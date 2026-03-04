# Inner Load Blocks

## Overview

This tutorial demonstrates the **inner load blocks** feature in SDDPlab.jl. Load blocks partition each stage into sub-periods with different demand levels and durations, enabling within-stage dispatch optimization. This is essential for capturing the economic dispatch differences between peak, shoulder, and off-peak periods without increasing the number of stages.

In the SDDP formulation with parallel blocks, the stage objective becomes:

$$\sum_{k=1}^{K} \tau_k \cdot c^\top x_k$$

where $\tau_k$ is the duration (hours) of block $k$ and $x_k$ is the dispatch in block $k$. The water balance aggregates turbined flow across blocks using duration weights $w_k = \tau_k / \sum_k \tau_k$.

## Study Description

The example models a single-bus system with 3 load blocks over 12 monthly stages:

| Component      | Details                                         |
| -------------- | ----------------------------------------------- |
| **Bus SYSTEM** | Single load center, deficit cost 500 \$/MWh     |
| **UHE1**       | Hydroelectric plant, 60 MW max, 100 hm3 storage |
| **UTE_BASE**   | Base-load thermal, 100 MW max, cost 10 \$/MWh   |
| **UTE_PEAK**   | Peaking thermal, 150 MW max, cost 50 \$/MWh     |

Load blocks within each stage (peak:shoulder:offpeak = 1:2:3 duration ratio):

| Block    | Demand | Duration (example: January, 744 h) |
| -------- | ------ | ---------------------------------- |
| peak     | 200 MW | 124 h                              |
| shoulder | 150 MW | 248 h                              |
| offpeak  | 80 MW  | 372 h                              |

Block durations vary per stage because they must sum to the stage duration
derived from the graph node datetimes (e.g., January = 744 h, February = 696 h).

## Configuration Walkthrough

### Block Configuration (`data/scenarios.jsonc`)

Blocks are defined per-stage in the `stage_blocks` section of the scenarios configuration. Each stage key maps to a block configuration with `mode` and `definitions`. Block durations must sum to the stage duration from the graph:

```json
"stage_blocks": {
    "1":  { "mode": "parallel", "definitions": [
        { "name": "peak", "duration_hours": 124.0 },
        { "name": "shoulder", "duration_hours": 248.0 },
        { "name": "offpeak", "duration_hours": 372.0 }
    ]},
    "2":  { "mode": "parallel", "definitions": [
        { "name": "peak", "duration_hours": 116.0 },
        { "name": "shoulder", "duration_hours": 232.0 },
        { "name": "offpeak", "duration_hours": 348.0 }
    ]}
}
```

The `mode` can be:

- `"parallel"`: A single water balance per hydro plant with block-weight aggregation (most common)
- `"chronological"`: Per-block water balances with intermediate storage variables (captures intra-stage storage dynamics)

### Block-Specific Load (`data/load.csv`)

When blocks are defined, the load CSV must include a `block` column matching the block names:

```
bus_id ,node_id ,value ,block
     1 ,      2 ,200.0 ,peak
     1 ,      2 ,150.0 ,shoulder
     1 ,      2 , 80.0 ,offpeak
     ...
```

Each `(bus_id, node_id, block)` triple must be unique. The `block` column value must exactly match the `name` field in the block definitions.

### Engine Configuration (`main.jsonc`)

Risk-neutral optimization with 50 iterations and the Expectation risk measure.

## Running the Example

```julia
using SDDPlab

study = SDDPlab.read_study("example/load_blocks")
model = SDDPlab.build(study)
SDDPlab.train(study, model)
artifact = SDDPlab.simulate(study, model)
```

## Expected Output

The simulation produces per-block dispatch results. Expected behavior:

- **Peak block** (200 MW demand): Both thermals and hydro are dispatched; the expensive peaking thermal (UTE_PEAK) runs during peak hours
- **Shoulder block** (150 MW demand): Hydro and base thermal handle most demand; peaking thermal may run at partial capacity
- **Off-peak block** (80 MW demand): Only hydro and the cheap base thermal are needed

The cost-to-go function accounts for the block-weighted water consumption, so the optimizer balances hydro usage across blocks to minimize the total weighted cost.

## Variations

- Switch to `"chronological"` mode and observe the creation of `BLOCK_STORAGE` intermediate variables
- Add a 4th block ("night") and redistribute durations across the four blocks
- Increase peak demand to 300 MW to force deficit in peak hours
- Add a non-controllable (solar) that produces only during shoulder/peak blocks
