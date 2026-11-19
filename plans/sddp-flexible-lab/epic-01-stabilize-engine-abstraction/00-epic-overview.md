# Epic 01: Stabilize Engine Abstraction

## Goal

Complete the `abstract-engine` branch refactoring and merge it into `main`. This epic resolves all TODOs, adds missing validation in the graph module, simplifies the validation pipeline with a declarative schema system, refactors the load representation to use the node-based graph instead of `stage_index`, and ensures comprehensive test coverage for the new architecture.

## Primary Agent

`hpc-julia-developer` -- This epic is infrastructure-heavy: merging branches, implementing validation pipelines, building schema infrastructure, refactoring type hierarchies, and writing comprehensive tests. All work follows established Julia patterns and requires expertise in Julia's type system, JuMP model construction, and test infrastructure.

## Scope

- Merge `abstract-engine` branch into `main` (or rebase onto `main`)
- Implement graph validators (currently empty stubs in `src/Scenarios/graph-validators.jl`)
- Implement FieldRule schema infrastructure for declarative validation
- Migrate all entities (System, Engine, Scenarios, StochasticProcess) to schema-driven validation
- Clean up dead validation code and document the schema module
- Refactor DeterministicLoad to reference graph nodes instead of raw `stage_index`
- Fix the `__add_load_balance!` TODO in `src/Engines/sddp/build.jl` to use the proper load representation
- Migrate all existing example cases (1dtoy, 1dsin, 1dsin_ar) to the new format
- Achieve full test coverage for Lab, Engines, Scenarios/graph, Study modules, and schema infrastructure
- Ensure backward compatibility: existing numerical results must be reproduced

## Tickets

| ID         | Title                                                      | Estimate | Agent               | Status    |
| ---------- | ---------------------------------------------------------- | -------- | ------------------- | --------- |
| ticket-001 | Merge abstract-engine branch into main                     | 2 pts    | hpc-julia-developer | completed |
| ticket-002 | Implement graph validators                                 | 3 pts    | hpc-julia-developer | completed |
| ticket-003 | Implement FieldRule schema infrastructure                  | 3 pts    | hpc-julia-developer | pending   |
| ticket-004 | Migrate System entities to schema validation               | 4 pts    | hpc-julia-developer | pending   |
| ticket-005 | Migrate Engine and Scenarios entities to schema validation | 4 pts    | hpc-julia-developer | pending   |
| ticket-006 | Cleanup validation pipeline and remove dead code           | 2 pts    | hpc-julia-developer | pending   |
| ticket-007 | Refactor load representation to node-based graph           | 4 pts    | hpc-julia-developer | pending   |
| ticket-008 | Migrate example cases to new input format                  | 2 pts    | hpc-julia-developer | pending   |
| ticket-009 | Add comprehensive test coverage for engine abstraction     | 4 pts    | hpc-julia-developer | pending   |

## Dependency Graph

```
ticket-001 (merge) [COMPLETED]
     |
     +---> ticket-002 (graph validators) [COMPLETED]
     |          |
     |          +---> ticket-003 (schema infrastructure)
     |                     |
     |                     +---> ticket-004 (System schema migration)
     |                     |          |
     |                     |          +---> ticket-005 (Engine/Scenarios schema migration)
     |                     |                     |
     |                     |                     +---> ticket-006 (cleanup dead code)
     |                     |                                |
     |                     +---> ticket-007 (load refactor) <--- ticket-006
     |                                |
     |                                +---> ticket-008 (examples) <--- ticket-007
     |
     +---> ticket-009 (tests) <--- ticket-002, ..., ticket-008
```

## Dependencies

- None (this is the foundation epic)

## Deliverables

- `abstract-engine` merged into `main` with all tests passing
- Graph validation catches malformed node/edge definitions
- Declarative FieldRule schema infrastructure replaces 40%+ of validation boilerplate
- All entities (System, Engine, Scenarios, StochasticProcess) use schema-driven validation
- Load representation uses graph nodes, not raw stage indices
- All three example cases work with the new format
- Test coverage for the engine abstraction layer and schema infrastructure at >= 80%
