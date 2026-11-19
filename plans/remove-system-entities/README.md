# Remove System Entities - Implementation Plan

## Progress Tracking

<!-- BEGIN plan-progress -->
| Ticket     | Title                                              | Epic    | Status  | Detail Level | Readiness | Quality | Badge |
| ---------- | -------------------------------------------------- | ------- | ------- | ------------ | --------- | ------- | ----- |
| ticket-001 | Remove the Entity Footprint from the SDDP Model    | epic-01 | pending | Detailed     | 0.96      | --      | --    |
| ticket-002 | Remove the Three Entities from the System Data Layer | epic-01 | pending | Detailed     | 0.94      | --      | --    |
| ticket-003 | Remove Entity Traces Outside the Package Source    | epic-01 | pending | Detailed     | 0.96      | --      | --    |
<!-- END plan-progress -->

**Design Fitness:** 1.00 (independent head score, gate 0.80) — scored by `spec-scorer` from the on-disk artifacts only; report: [reports/plan.scorer.1.md](reports/plan.scorer.1.md). Design review: 1 critique round ([design/critique/round-1.md](design/critique/round-1.md)), 1 finding (F1-001, ACKNOWLEDGED) resolved by ADR-005; council sign-off: 2/2 seats ([design/signoff.md](design/signoff.md)), 1 objection (ADR-003) resolved by ADR-005.

## Overview

SDDPlab's scope is being reduced toward a friendlier laboratory architecture. This plan removes three system entities completely, as if they had never been programmed: non-controllable generation, energy contracts and pumping stations. Their types, schemas, validators, LP footprint, variable symbols, scaling keys, output files, tests, examples, tutorials, documentation mentions and v3.0.0 CHANGELOG entries all go, with no shim, flag, compatibility path or removal note. Systems that never used the entities keep the same LP model, scaling factors and output files.

## Development Branch

The development branch is created **from `feat/sddp-flexible-lab`**, not from `main` (R8, ADR-004):

```bash
git switch -c feat/remove-system-entities feat/sddp-flexible-lab
```

ticket-001 runs this as its first step. All tickets land as normal commits on `feat/remove-system-entities`; no history is rewritten and `plans/sddp-flexible-lab/**` stays untouched (R13).

## Navigation

- [Master plan](00-master-plan.md) — requirements R1-R13, decisions ADR-001 to ADR-005 (ADR-003 superseded by ADR-005), chain contracts, final grep gate
- [Epic 01: Remove System Entities](epic-01-remove-system-entities/00-epic-overview.md)
  - [ticket-001 Remove the Entity Footprint from the SDDP Model](epic-01-remove-system-entities/ticket-001-remove-entity-model-footprint.md)
  - [ticket-002 Remove the Three Entities from the System Data Layer](epic-01-remove-system-entities/ticket-002-remove-entity-system-layer.md)
  - [ticket-003 Remove Entity Traces Outside the Package Source](epic-01-remove-system-entities/ticket-003-remove-entity-traces-outside-package.md)
- [Intake](design/intake.md) and council briefs ([hpc-julia-developer](design/council/hpc-julia-developer.brief.md), [sddp-specialist](design/council/sddp-specialist.brief.md))

## Tech Stack

- Julia 1.10 (CI also runs `1`), SDDP.jl, JuMP.jl, HiGHS
- Documenter.jl for the docs site
- JuliaFormatter v1, Blue style (`.JuliaFormatter.toml`, enforced by CI `format_check.yml`)

## Specialist Chain

```
sddp-specialist (formulation: LP and scaling invariance contract; ADR-005)
  -> hpc-julia-developer (implementation: ticket-001, ticket-002, ticket-003)
```

| Agent | Role | Tickets |
| --- | --- | --- |
| `sddp-specialist` | Council consultant: invariance proof for entity-free systems, R7 verification approach | -- (design only) |
| `hpc-julia-developer` | Implementer | ticket-001, ticket-002, ticket-003 |

## Epics

| Epic | Name | Tickets | Status | Primary Agent |
| --- | --- | --- | --- | --- |
| 01 | Remove System Entities | 3 | Pending | hpc-julia-developer |

## Dependency Graph

```
ticket-001-remove-entity-model-footprint        (branch; LP footprint, Lab symbols, scaling keys, output files; R7 dump)
        |
        v
ticket-002-remove-entity-system-layer           (types, SystemData 7 -> 4 fields, schemas, validators, tests)
        |
        v
ticket-003-remove-entity-traces-outside-package (examples, tutorials, docs mentions, CHANGELOG; final grep gate)
```

## Execution Order

1. `ticket-001-remove-entity-model-footprint.md` — creates `feat/remove-system-entities` from `feat/sddp-flexible-lab`, removes every engine-side and Lab-side use of the entities while the types still exist, and proves R7 with a one-off, uncommitted dump taken at the base commit and after its edits (ADR-005): parameterized subproblems and scaling factors of five examples under `NoScaling` and `AutoScaling`, plus a perturbed `compute_scaling_factors` case. The base dump stays in `/tmp/sddplab-r7` for ticket-002.
2. `ticket-002-remove-entity-system-layer.md` — deletes the types, fields, accessors, schemas, validators and dedicated tests; `src/` and `test/` are then free of every trace. It then runs the mandatory R7 rerun of the same dump against ticket-001's base dump (ADR-005), which checks the `apply_scaling` rewrite, and deletes `/tmp/sddplab-r7`.
3. `ticket-003-remove-entity-traces-outside-package.md` — deletes the examples and tutorials, cleans the shared docs and CHANGELOG, and runs the final whole-repo grep gate and the R13 checks.

Every ticket leaves `using SDDPlab` working and `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` green, and passes the JuliaFormatter v1 fixpoint.

## Decision Records

| ADR | Title | Status | Reversibility | Requirements | Implemented by |
| --- | ----- | ------ | ------------- | ------------ | -------------- |
| ADR-001 | Cut the removal into one epic of three tickets, consumers first: model footprint, then System data layer, then examples/docs/CHANGELOG | accepted | two-way | R9, R10, R1, R2, R3, R4, R5, R11, R12 | ticket-001, ticket-002, ticket-003 |
| ADR-002 | Shrink every affected signature by deleting the entity parameters, locals and the three SystemData fields outright (positional arity 7 to 4) | accepted | one-way | R1, R2, R3, R6, R7, R10 | ticket-001, ticket-002 |
| ADR-003 | Verify R7 with the existing suite plus a one-off, uncommitted before/after dump of every node subproblem and of the ScalingConfig factors | superseded (by ADR-005) | two-way | R7, R6, R9 | -- |
| ADR-004 | Develop on a new branch feat/remove-system-entities created from feat/sddp-flexible-lab, with normal commits and no history rewrite | accepted | two-way | R8, R13 | ticket-001, ticket-003 |
| ADR-005 | Verify R7 with the existing suite plus a one-off, uncommitted dump of parameterized node subproblems and ScalingConfig factors under NoScaling and AutoScaling, a perturbed compute_scaling_factors case, and a mandatory rerun after ticket-002 (supersedes ADR-003) | accepted | two-way | R7, R6, R9 | ticket-001, ticket-002 |

## Final Gate

```bash
git grep -n -i -E 'noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc' -- . ':!plans/' ':!LICENSE'
# required after ticket-003: no output, exit status 1
```
