# ticket-026 Add Markov Chain State Transitions

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify MarkovianGraph integration with existing graph validators)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Add support for Markov chain-based scenario graphs where nodes within a stage represent different system states (e.g., wet/dry hydrological regimes) with transition probabilities between them. This enables regime-switching models where the stochastic process parameters vary by Markov state.

## Anticipated Scope

- **Files likely to be modified**: `src/Scenarios/graph.jl`, `src/Scenarios/Scenarios.jl`, `src/Engines/sddp/build.jl` (graph construction for Markov chains), `src/StochasticProcess/StochasticProcess.jl`
- **Key decisions needed**: Whether Markov states are encoded in the graph structure (multiple nodes per stage) or as a separate concept. How transition probabilities are specified in JSONC.
- **Open questions**:
  - Should Markov states be defined in the graph.jsonc or in the scenarios.jsonc?
  - How do Markov states interact with the existing stochastic process SAA generation?
  - Can SDDP.jl's `MarkovianGraph` be used directly?

## Dependencies

- **Blocked By**: ticket-025
- **Blocks**: ticket-027

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
