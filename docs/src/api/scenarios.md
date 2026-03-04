# Scenarios

The scenarios module defines the SDDP scenario tree structure, inflow data,
load profiles, and Markov chain state transitions. All types in this module are
constructed from your `scenarios.jsonc` configuration file.

## Scenarios Container

```@docs
ScenariosData
```

## Accessing Scenario Data

```@docs
get_scenarios
get_graph
get_load
get_block_config
get_markov_chain
get_stochastic_process
```

## Scenario Graph

```@docs
Graph
Node
Edge
get_number_of_stages
get_root_node_id
```

## Inflow Scenarios

```@docs
InflowScenarios
```

## Inner Load Blocks

```@docs
BlockConfig
Block
has_blocks
num_blocks
get_block_names
get_block_durations
get_block_weights
```

## Markov Chain

```@docs
AbstractMarkovChain
NoMarkovChain
MarkovChainConfig
has_markov_chain
num_markov_states
```
