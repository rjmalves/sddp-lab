module Scenarios

using JuMP

using Random
using Dates
using ..Lab
using ..Utils
using ..StochasticProcess

import Base: length

"""
    InflowScenarios

Container for inflow stochastic processes, keyed by Markov state index.
In the non-Markov case (single process), the key is always `1`.

# Fields

  - `stochastic_process`: Dict mapping Markov state index (Int) to an
    [`AbstractStochasticProcess`](@ref) that generates inflow SAA samples.

See also: [`ScenariosData`](@ref), [`get_stochastic_process`](@ref)
"""
struct InflowScenarios
    stochastic_process::Dict{Int,AbstractStochasticProcess}
end

"""
    LoadScenarios

Abstract base type for load scenario data containers. Concrete subtypes handle
flat and block-structured load profiles.
"""
abstract type LoadScenarios end

"""
    Node

A node in the SDDP scenario graph, representing one time stage (or sub-stage).

# Fields

  - `id`: Unique integer node identifier.
  - `stage`: SDDP stage index (1-based).
  - `start_datetime`: Wall-clock start time of this stage.
  - `end_datetime`: Wall-clock end time of this stage.

See also: [`Graph`](@ref), [`Edge`](@ref)
"""
struct Node
    id::Integer
    stage::Integer
    start_datetime::DateTime
    end_datetime::DateTime
end

"""
    Edge

A directed edge in the SDDP scenario graph, connecting two [`Node`](@ref)
instances with a transition probability and discount rate.

# Fields

  - `source`: Reference to the source [`Node`](@ref).
  - `target`: Reference to the target [`Node`](@ref).
  - `probability`: Transition probability (must be in `[0, 1]`).
  - `discount_rate`: Per-stage discount factor applied to future costs.

See also: [`Graph`](@ref), [`Node`](@ref)
"""
struct Edge
    source::Ref{Node}
    target::Ref{Node}
    probability::Real
    discount_rate::Real
end

"""
    Graph

The SDDP scenario tree structure. Contains all nodes across all stages and the
edges encoding transition probabilities.

# Fields

  - `nodes`: All [`Node`](@ref) objects in the graph, in arbitrary order.
  - `edges`: All [`Edge`](@ref) objects defining the tree structure.

See also: [`ScenariosData`](@ref), [`get_graph`](@ref),
[`get_number_of_stages`](@ref), [`get_root_node_id`](@ref)
"""
struct Graph
    nodes::Vector{Node}
    edges::Vector{Edge}
end

function __get_ids(s::LoadScenarios) end
function length(s::LoadScenarios) end

include("blocks.jl")

include("markov-validators.jl")
include("markov.jl")

"""
    ScenariosData <: InputModule

Root container for all scenario-related configuration. Produced by parsing the
`scenarios.jsonc` file referenced in `main.jsonc`.

# Fields

  - `seed`: Random seed used for SAA generation (reproducibility).
  - `initial_season`: Season index (1-based) corresponding to the first stage.
  - `branchings`: Number of scenario branchings per stage in the training tree.
  - `graph`: [`Graph`](@ref) defining the SDDP scenario tree topology.
  - `inflow`: [`InflowScenarios`](@ref) container with stochastic process(es).
  - `load`: `LoadScenarios` with deterministic or block load profiles.
  - `block_configs`: `Dict{Int, BlockConfig}` mapping stage index to per-stage
    [`BlockConfig`](@ref). Stages absent from the dict use `default_block_config()`.
  - `markov_chain`: [`AbstractMarkovChain`](@ref) for Markov state transitions.

See also: [`get_scenarios`](@ref), [`get_graph`](@ref), [`get_block_config`](@ref)
"""
struct ScenariosData <: InputModule
    seed::Integer
    initial_season::Integer
    branchings::Integer
    graph::Graph
    inflow::InflowScenarios
    load::LoadScenarios
    block_configs::Dict{Int,BlockConfig}
    markov_chain::AbstractMarkovChain
end

function __get_load(bus_id::Integer, node_id::Integer, load::LoadScenarios)::Real end

function __get_load(
    bus_id::Integer, node_id::Integer, block_idx::Integer, load::LoadScenarios
)::Real
    return __get_load(bus_id, node_id, load)
end

"""
    get_load(bus_id, node_id, scenarios) -> Real

Return the deterministic load demand (MW) for bus `bus_id` at scenario node `node_id`.

See also: [`ScenariosData`](@ref), [`get_block_config`](@ref)
"""
function get_load(bus_id::Integer, node_id::Integer, scenarios::ScenariosData)::Real
    return __get_load(bus_id, node_id, scenarios.load)
end

"""
    get_load(bus_id, node_id, block_idx, scenarios) -> Real

Return the load demand (MW) for bus `bus_id` at node `node_id` and block
`block_idx`. When inner load blocks are active, returns the block-specific load;
otherwise returns the stage-level load.

!!! note

    This overload uses `get_block_config(scenarios)` (stage-1 config) for
    backward compatibility. Ticket-045 will add per-stage dispatch.

See also: [`has_blocks`](@ref), [`BlockConfig`](@ref)
"""
function get_load(
    bus_id::Integer, node_id::Integer, block_idx::Integer, scenarios::ScenariosData
)::Real
    bc = get_block_config(scenarios)
    if has_blocks(bc)
        block_name = bc.blocks[block_idx].name
        return __get_load_by_block_name(bus_id, node_id, block_name, scenarios.load)
    else
        return __get_load(bus_id, node_id, scenarios.load)
    end
end

"""
    get_block_config(scenarios, stage) -> BlockConfig

Return the [`BlockConfig`](@ref) for stage `stage` from a [`ScenariosData`](@ref)
object. Falls back to `default_block_config()` when the stage has no explicit entry.

# Example

```julia
bc = get_block_config(scenarios, 2)
has_blocks(bc)  # true if stage 2 has explicit blocks defined
```

See also: [`BlockConfig`](@ref), [`has_blocks`](@ref), [`default_block_config`](@ref)
"""
function get_block_config(scenarios::ScenariosData, stage::Int)::BlockConfig
    return get(scenarios.block_configs, stage, default_block_config())
end

"""
    get_block_config(scenarios) -> BlockConfig

Return the [`BlockConfig`](@ref) for stage 1 from a [`ScenariosData`](@ref) object.

!!! warning

    Deprecated. Use `get_block_config(scenarios, stage)` to retrieve the per-stage
    config explicitly. This single-argument form emits a deprecation warning and
    returns the stage-1 config (or an error if configs differ across stages).

See also: [`BlockConfig`](@ref), [`get_block_config(::ScenariosData, ::Int)`](@ref)
"""
function get_block_config(scenarios::ScenariosData)::BlockConfig
    Base.depwarn(
        "get_block_config(scenarios) is deprecated. " *
        "Use get_block_config(scenarios, stage) to retrieve the per-stage BlockConfig.",
        :get_block_config,
    )
    return get(scenarios.block_configs, 1, default_block_config())
end

"""
    get_graph(scenarios) -> Graph

Return the scenario [`Graph`](@ref) from a [`ScenariosData`](@ref) object.

See also: [`Graph`](@ref), [`get_number_of_stages`](@ref)
"""
function get_graph(scenarios::ScenariosData)
    return scenarios.graph
end

"""
    get_number_of_stages(g) -> Integer

Return the number of distinct stages in a scenario [`Graph`](@ref).

See also: [`Graph`](@ref), [`get_root_node_id`](@ref)
"""
function get_number_of_stages(g::Graph)::Integer
    return length(unique(n.stage for n in g.nodes))
end

"""
    get_root_node_id(g) -> Integer

Return the ID of the root node (stage 1, no incoming edges) in a scenario
[`Graph`](@ref).

See also: [`Graph`](@ref), [`Node`](@ref)
"""
function get_root_node_id(g::Graph)::Integer
    node_ids = Set(n.id for n in g.nodes)
    target_ids = Set(e.target[].id for e in g.edges)
    return first(setdiff(node_ids, target_ids))
end

"""
    get_markov_chain(scenarios) -> AbstractMarkovChain

Return the [`AbstractMarkovChain`](@ref) from a [`ScenariosData`](@ref) object.

See also: [`AbstractMarkovChain`](@ref), [`has_markov_chain`](@ref)
"""
function get_markov_chain(scenarios::ScenariosData)
    return scenarios.markov_chain
end

"""
    get_stochastic_process(inflow) -> AbstractStochasticProcess

Return the single [`AbstractStochasticProcess`](@ref) from an
[`InflowScenarios`](@ref) container (non-Markov mode).

Throws an error if more than one process is present. Use
`get_stochastic_process(inflow, state)` for Markov mode.

See also: [`InflowScenarios`](@ref), [`AbstractStochasticProcess`](@ref)
"""
function get_stochastic_process(inflow::InflowScenarios)
    if length(inflow.stochastic_process) != 1
        error(
            "Expected single stochastic process, got $(length(inflow.stochastic_process)) processes. Use get_stochastic_process(inflow, state) for Markov mode.",
        )
    end
    return first(values(inflow.stochastic_process))
end

"""
    get_stochastic_process(inflow, state) -> AbstractStochasticProcess

Return the [`AbstractStochasticProcess`](@ref) for Markov state `state` from an
[`InflowScenarios`](@ref) container.

See also: [`InflowScenarios`](@ref), [`MarkovChainConfig`](@ref)
"""
function get_stochastic_process(inflow::InflowScenarios, state::Int)
    return inflow.stochastic_process[state]
end

include("graph-validators.jl")
include("graph.jl")

include("inflow-validators.jl")
include("inflow.jl")

include("load-validators.jl")
include("load.jl")

include("scenariosdata-validators.jl")
include("scenariosdata.jl")

export ScenariosData,
    Block,
    BlockConfig,
    AbstractMarkovChain,
    NoMarkovChain,
    MarkovChainConfig,
    has_markov_chain,
    num_markov_states,
    get_markov_chain,
    get_stochastic_process,
    add_uncertainties!,
    generate_saa,
    get_load,
    get_block_config,
    get_scenarios,
    get_graph,
    get_number_of_stages,
    get_root_node_id,
    has_blocks,
    num_blocks,
    get_block_names,
    get_block_durations,
    get_block_weights,
    Graph,
    Node,
    Edge,
    InflowScenarios

end
