# Pumped Storage Hydroelectricity

## Overview

This tutorial demonstrates the **pumping station** feature in SDDPlab.jl. A pumping station transfers water from a lower reservoir to an upper reservoir, consuming electrical power in the process. This enables temporal energy arbitrage: pump water uphill during low-demand periods (consuming cheap energy) and release it through turbines during high-demand periods (generating valuable energy).

In the SDDP formulation, a pumping station introduces:

- A decision variable for pumped flow (m3/s)
- An additional term in the reservoir balance equations (source loses water, destination gains water)
- A power consumption term in the load balance (pumping consumes MW from the bus)

## Study Description

The example models a single-bus system with pumped storage over 12 monthly stages:

| Component      | Details                                                                 |
| -------------- | ----------------------------------------------------------------------- |
| **Bus SYSTEM** | Single load center (70 MW demand), deficit cost 500 \$/MWh              |
| **UPPER**      | Upper reservoir, 100 hm3 storage, 50 MW max generation, initial 60 hm3  |
| **LOWER**      | Lower reservoir, 80 hm3 storage, 40 MW max generation, initial 40 hm3   |
| **UTE1**       | Thermal backup, 30 MW max, cost 20 \$/MWh                               |
| **PUMP**       | Pumps water from LOWER to UPPER, consumption 0.5 MW/(m3/s), max 40 m3/s |

Both reservoirs receive stochastic inflows (correlated via Gaussian copula). The pump creates an operational cycle where excess water in the lower reservoir can be transferred to the upper reservoir to be released later.

A CVaR risk measure with `alpha=0.5` and `lambda=0.5` provides moderate risk aversion, appropriate for systems where storage management is critical.

## Configuration Walkthrough

### System Configuration (`data/system.jsonc`)

The pumping station is defined inline (required because the `flow` field is a nested object):

```json
"pumpingstations": {
    "entities": [
        {
            "id": 1,
            "name": "PUMP_LOWER_TO_UPPER",
            "bus_id": 1,
            "source_hydro_id": 2,
            "destination_hydro_id": 1,
            "consumption_mw_per_m3s": 0.5,
            "flow": {
                "min_m3s": 0.0,
                "max_m3s": 40.0
            }
        }
    ]
}
```

Key fields:

- `source_hydro_id`: The reservoir that loses water (LOWER, id=2)
- `destination_hydro_id`: The reservoir that gains water (UPPER, id=1)
- `consumption_mw_per_m3s`: Electrical power consumed per unit of pumped flow
- `flow.max_m3s`: Maximum pumping rate

### Risk Measure (`main.jsonc`)

```json
"risk_measure": {
    "kind": "CVaR",
    "params": {
        "alpha": 0.5,
        "lambda": 0.5
    }
}
```

This uses a 50/50 blend of expectation and CVaR at the 50% confidence level.

## Running the Example

```julia
using SDDPlab, HiGHS

study = SDDPlab.read_study("example/pumped_storage")
model = SDDPlab.build(study, HiGHS.Optimizer)
SDDPlab.train(study, model)
artifact = SDDPlab.simulate(study, model)
```

## Expected Output

The simulation results show the pumping station being activated when:

- The lower reservoir has excess water that would otherwise be spilled
- Thermal generation cost exceeds the effective pumping cost (accounting for round-trip efficiency)
- Future expected value of stored water in the upper reservoir justifies the pumping cost

Key variables to inspect: `PUMPED_FLOW` (m3/s transferred), `PUMP_POWER` (MW consumed), and `STORED_VOLUME` for both reservoirs.

## Variations

- Increase `consumption_mw_per_m3s` to 1.0 MW/(m3/s) to make pumping more expensive and observe reduced pumping activity
- Add a second bus with a cheaper thermal plant to create spatial arbitrage incentives
- Increase CVaR `lambda` to 0.9 for stronger risk aversion and observe more conservative storage management
- Add load blocks (peak/offpeak) to create within-stage temporal arbitrage for the pump
