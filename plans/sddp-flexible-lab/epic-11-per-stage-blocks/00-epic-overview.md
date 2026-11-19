# Epic 11: Per-Stage Block Architecture and Output Reform

## Goal

Migrate `BlockConfig` from a single global configuration applied uniformly across all stages to a per-stage property, where each stage can have its own block mode (parallel/chronological) and block definitions. Reform the output Parquet format to use explicit block columns (`block_index`, `block_duration_hours`) instead of the current variable name mangling pattern (`THERMAL_GENERATION_B1`, `THERMAL_GENERATION_B2`).

## Primary Agent

`hpc-julia-developer` for infrastructure changes (ticket-044, ticket-046, ticket-047). `sddp-specialist` for subproblem builder modifications (ticket-045) that affect LP formulation and cut generation.

## Scope

- Per-stage `BlockConfig` in `ScenariosData` and `Node`/stage mapping
- Backward-compatible parsing: global "blocks" key applies to all stages with deprecation warning
- Per-stage block validation: block duration sum must equal stage `tau`
- Subproblem builder updated to look up per-stage block config
- Output Parquet format reformed with explicit block columns
- Full test coverage including E2E with per-stage blocks

## Tickets

| ID         | Title                                               | Estimate | Agent               |
| ---------- | --------------------------------------------------- | -------- | ------------------- |
| ticket-044 | Restructure BlockConfig from global to per-stage    | 4 pts    | hpc-julia-developer |
| ticket-045 | Update subproblem builder for per-stage blocks      | 4 pts    | sddp-specialist     |
| ticket-046 | Reform output Parquet format with block columns     | 3 pts    | hpc-julia-developer |
| ticket-047 | Update tests and example cases for per-stage blocks | 3 pts    | hpc-julia-developer |

## Dependencies

- Epic 06 (Subproblem Structure) must be complete -- it introduced the current global `BlockConfig`, block-indexed variables, parallel/chronological water balance, and `tau_k` weighting. All 3 tickets in epic 06 are completed.
- Epic 10 (Documentation) should be complete so docs can be updated alongside.

## Key Design Decisions

1. **Per-stage storage**: `BlockConfig` becomes a `Dict{Int, BlockConfig}` mapping stage index to config, stored on `ScenariosData`. Nodes at the same stage share the same config.
2. **Backward compatibility**: A global `"blocks"` key in `scenarios.jsonc` applies to all stages. A new `"stage_blocks"` key allows per-stage definitions.
3. **Variable dimensions**: Since each SDDP.jl node's subproblem is built independently, different `K` values per stage are naturally supported -- no shared variable dimension across stages.
4. **Output format**: The `_B{k}` name mangling in `__increase_dataframe!` is replaced by a `block_index` column and a `block_duration_hours` column.
