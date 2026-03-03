# Markov Chain Inflow States

## Overview

This tutorial demonstrates **Markov chain state transitions** for stochastic inflow modeling in SDDPlab.jl. Instead of a single stochastic process for inflows, the system transitions between discrete states (e.g., "wet" and "dry" hydrological regimes) according to a Markov chain. Each state has its own inflow distribution, capturing regime-switching behavior that is common in hydrology.

In the SDDP policy graph, Markov states multiply the number of nodes at each stage. For $S$ Markov states and $T$ stages, the policy graph has $S \times T$ nodes (plus the root). The transition probabilities define the edges between stages, and each node carries a state-specific stochastic process for inflow generation.

## Study Description

The example models a 2-hydro cascade system with 2 Markov states over 12 monthly stages:

| Component      | Details                                                      |
| -------------- | ------------------------------------------------------------ |
| **Bus SYSTEM** | Single load center (70 MW demand), deficit cost 500 \$/MWh   |
| **UHE1**       | Upstream hydro, 50 MW max, 100 hm3 storage, cascades to UHE2 |
| **UHE2**       | Downstream hydro, 40 MW max, 80 hm3 storage                  |
| **UTE1**       | Thermal backup, 40 MW max, cost 25 \$/MWh                    |

Markov states:

- **State 1 (Wet)**: Higher inflow means (LogNormal mu = 3.0--3.8) for both hydros
- **State 2 (Dry)**: Lower inflow means (LogNormal mu = 1.8--2.8) for both hydros

Transition matrix (stages 2--12):

```
[[0.7, 0.3],
 [0.4, 0.6]]
```

This means wet periods tend to persist (70% chance of staying wet) and dry periods are moderately sticky (60% chance of staying dry).

## Configuration Walkthrough

### Markov Chain (`data/scenarios.jsonc`)

The Markov chain is defined in the `markov_chain` section:

```json
"markov_chain": {
    "transition_matrices": [
        [[0.5, 0.5]],
        [[0.7, 0.3], [0.4, 0.6]],
        ...
    ]
}
```

The first matrix is 1xN (root distribution: equal probability of starting in either state). Subsequent matrices are NxN (row-stochastic). Each row sums to 1.0.

### Per-State Inflow Processes

The `inflow.stochastic_process` section uses a multi-process dictionary with string-integer keys:

```json
"inflow": {
    "stochastic_process": {
        "1": {
            "kind": "Naive",
            "params": { "file": "inflow_wet.jsonc" }
        },
        "2": {
            "kind": "Naive",
            "params": { "file": "inflow_dry.jsonc" }
        }
    }
}
```

Each key corresponds to a Markov state (1-indexed). The number of keys must equal the number of Markov states defined by the transition matrices.

### Risk Measure

A strongly risk-averse CVaR with `alpha=0.2` and `lambda=0.9`:

```json
"risk_measure": {
    "kind": "CVaR",
    "params": { "alpha": 0.2, "lambda": 0.9 }
}
```

This places 90% weight on the CVaR component at the 20th percentile, making the policy very conservative -- appropriate for a system that must hedge against transitions to the dry state.

## Running the Example

```julia
using SDDPlab

study = SDDPlab.read_study("example/markov_var")
model = SDDPlab.build(study)
SDDPlab.train(study, model)
artifact = SDDPlab.simulate(study, model)
```

## Expected Output

The trained policy differentiates its decisions based on the Markov state:

- In **wet** states, more aggressive hydro dispatch (lower water value) since high inflows are expected to persist
- In **dry** states, more conservative hydro dispatch (higher water value) with increased thermal backup

The simulation generates trajectory paths that switch between wet and dry states according to the Markov transition probabilities.

## Variations

- Add a third Markov state ("normal") with a 3x3 transition matrix
- Replace the `Naive` stochastic process with `VectorAutoRegressive` for each state to capture temporal correlations within each regime
- Reduce `lambda` to 0.0 (pure expectation) and compare the dispatch policy with the risk-averse version
- Add `validation` configuration to the engine for out-of-sample testing
