# Renewable Generation and Energy Contracts

## Overview

This tutorial demonstrates two advanced system elements introduced in SDDPlab.jl:

- **Non-controllable generation**: Wind or solar plants whose output is injected into the power balance but cannot be dispatched. Excess generation can be curtailed at a cost.
- **Energy contracts**: Import and export agreements that allow buying power from or selling power to external markets at fixed prices, subject to capacity limits.

These features are essential for modeling modern power systems where renewable penetration creates surplus energy in some periods and deficits in others, and bilateral contracts provide price arbitrage opportunities.

## Study Description

The example models a 2-bus power system over 12 monthly stages:

| Component            | Details                                                                       |
| -------------------- | ----------------------------------------------------------------------------- |
| **Bus NORTH**        | Main load center (80 MW demand), deficit cost 500 \$/MWh                      |
| **Bus SOUTH**        | Secondary load center (40 MW demand), deficit cost 500 \$/MWh                 |
| **UHE1**             | Hydroelectric plant on bus NORTH, 60 MW max, 100 hm3 storage                  |
| **UTE1**             | Thermal plant on bus NORTH, 40 MW max, cost 25 \$/MWh                         |
| **WIND1**            | Non-controllable wind farm on bus SOUTH, 50 MW max, curtailment cost 5 \$/MWh |
| **IMPORT_SPOT**      | Import contract on bus NORTH, up to 50 MW at 80 \$/MWh                        |
| **EXPORT_BILATERAL** | Export contract on bus SOUTH, up to 40 MW at -30 \$/MWh (revenue)             |
| **NORTH_SOUTH**      | Transmission line, 100 MW capacity                                            |

Inflows follow a Naive stochastic process with LogNormal distributions exhibiting seasonal variation (wetter in summer, drier in winter).

## Configuration Walkthrough

### System Configuration (`data/system.jsonc`)

The key additions compared to a basic system are the `noncontrollables` and `energycontracts` sections:

```json
"noncontrollables": {
    "file": "noncontrollables.csv",
    "default_values": {}
}
```

The non-controllable CSV (`data/noncontrollables.csv`) defines:

```
id ,name    ,bus_id ,max_generation ,curtailment_cost
 1 ,"WIND1" ,     2 ,          50.0 ,             5.0
```

The `curtailment_cost` penalizes wasted renewable energy, incentivizing the optimizer to use wind generation before resorting to thermal or imports.

Energy contracts use inline JSONC definitions (required because the `limits` field is a nested object):

```json
"energycontracts": {
    "entities": [
        {
            "id": 1,
            "name": "IMPORT_SPOT",
            "bus_id": 1,
            "type": "import",
            "price_per_mwh": 80.0,
            "limits": { "min_mw": 0.0, "max_mw": 50.0 }
        },
        {
            "id": 2,
            "name": "EXPORT_BILATERAL",
            "bus_id": 2,
            "type": "export",
            "price_per_mwh": -30.0,
            "limits": { "min_mw": 0.0, "max_mw": 40.0 }
        }
    ]
}
```

Note that `type` must be exactly `"import"` or `"export"` (lowercase). Export contracts typically have a negative `price_per_mwh` to represent revenue.

### Engine Configuration (`main.jsonc`)

The engine uses risk-neutral optimization (Expectation) with 50 iterations:

```json
"risk_measure": {
    "kind": "Expectation",
    "params": {}
}
```

## Running the Example

```julia
using SDDPlab

study = SDDPlab.read_study("example/renewable_contracts")
model = SDDPlab.build(study)
SDDPlab.train(study, model)
artifact = SDDPlab.simulate(study, model)
```

## Expected Output

After training, the SDDP lower bound converges within 50 iterations. The simulation produces dispatch trajectories showing:

- **Wind generation** injected at bus SOUTH up to the available capacity
- **Import contract** activated on bus NORTH when hydro + thermal is insufficient
- **Export contract** activated on bus SOUTH when wind surplus exceeds local demand plus line capacity
- **Curtailment** occurring only when wind output exceeds the sum of local demand, export capacity, and line capacity

## Variations

- Increase the wind farm's `max_generation` to 100 MW and observe higher curtailment and export volumes
- Add a second non-controllable (solar) on bus NORTH with different seasonal patterns
- Change the import price to 40 \$/MWh (cheaper than thermal) and observe the shift in dispatch priority
- Switch to a risk-averse CVaR measure to see how import/export contracts provide hedging value
