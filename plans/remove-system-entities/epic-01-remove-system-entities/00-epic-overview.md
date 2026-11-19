# Epic 01: Remove System Entities

## Goal

Remove the non-controllable generation, energy contract and pumping station entities from SDDPlab completely, as if they had never been programmed (R1-R6, R10-R12), while every system that never used them builds the same LP, the same retained scaling factors and the same output files (R7). The epic is the whole plan (ADR-001, R9).

## Branch

All tickets run on `feat/remove-system-entities`, created from `feat/sddp-flexible-lab` (R8, ADR-004):

```bash
git switch -c feat/remove-system-entities feat/sddp-flexible-lab
```

ticket-001 creates the branch; ticket-002 and ticket-003 verify they are on it. Work lands as normal commits; no history is rewritten and `plans/sddp-flexible-lab/**` is not touched (R13).

## Tickets

| Order | Ticket | Removes | Agent | Tier | Door |
| --- | --- | --- | --- | --- | --- |
| 1 | `ticket-001-remove-entity-model-footprint.md` | LP footprint in `build.jl`, the five Lab symbols and their exports, the scaling inputs and keys, the unscale branches, the six output files, the pump maps and load-balance locals in `test/test-load-blocks.jl` | `hpc-julia-developer` | complex | one-way (exported symbols, output file names) |
| 2 | `ticket-002-remove-entity-system-layer.md` | the six dedicated `src/System` files, six types, three `SystemData` fields, six accessors, optional-key branches, re-exports, the `apply_scaling` rebuild, three dedicated tests, the 7-argument test fixtures, two example testsets | `hpc-julia-developer` | complex | one-way (exported types, `SystemData` arity, input keys) |
| 3 | `ticket-003-remove-entity-traces-outside-package.md` | two example directories, two tutorials, their `docs/make.jl` entries, the shared-docs mentions, the v3.0.0 CHANGELOG entries | `hpc-julia-developer` | standard | two-way (documentation only) |

Dependency chain: ticket-001 -> ticket-002 -> ticket-003. The order is forced by Julia's load-time resolution of method-signature types: every consumer of the entity types must be gone (ticket-001) before the types are deleted (ticket-002), and the examples stay loadable until ticket-003 deletes them because the generic reader ignores unknown `system.jsonc` keys after ticket-002.

## Structure Budget

Deletion only. This epic introduces no abstraction, layer, module, type, function, parameter, file, test, configuration key, dependency or compatibility path. The only authored text is the replacement prose fixed verbatim in ticket-003 (two docs sentences and one CHANGELOG line). In-scope cleanup is limited to what the removal itself makes dead (R6, R7): orphaned parameters, locals, imports, exports and docstring cross-references. No debt ticket is needed, because the plan takes no deliberate shortcut.

## Per-Ticket Gate

Every ticket leaves `using SDDPlab` working and passes, in this order:

1. its grep gate (a successful `using SDDPlab` is not proof of a clean removal: Julia resolves global names inside function bodies only at call time);
2. `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` exits 0 with no retained `@test` line edited;
3. the JuliaFormatter v1 Blue-style fixpoint over `src`, `test` and `docs` (CI `format_check.yml` fails on any formatter diff).

The exact commands are embedded in each ticket's Technical Details.

## Exit Criteria

- `git grep -n -i -E '<final pattern from 00-master-plan.md>' -- . ':!plans/' ':!LICENSE'` prints nothing and exits 1.
- `Pkg.test()` and the docs build exit 0 on `feat/remove-system-entities`.
- The R7 dump of ADR-005 was compared with the base-commit dump after ticket-001 (AC3) and again after ticket-002 (AC6). For the five remaining examples, under both `NoScaling` and `AutoScaling`, the parameterized subproblems were byte-identical or within 4 ULP through MOI. Every factors file, including the perturbed `compute_scaling_factors` case, differed only by the three removed keys.
