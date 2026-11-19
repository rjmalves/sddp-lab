# Intake: Remove System Entities

- **Mode:** INTAKE. This file holds data only: requirements, domain classification, roster and questions. It contains no master plan, epics, tickets, decision records or state file.
- **Plan dir:** `plans/remove-system-entities`
- **Repository:** `SDDPlab` (Julia, v3.0.0), HEAD `d16b8ee` on `feat/sddp-flexible-lab`, working tree clean
- **Date:** 2026-11-10

## Source spec

The operator's words, in Portuguese:

> De forma macro, o repositório em questão deve sofrer algumas reduções de escopo, bem como algumas simplificações visando uma arquitetura mais amigável, dado que o repositório em questão trata-se de um laboratório para desenvolvimento e prospecção de novas metodologias. Isto posto, minha atividade inicial abarca a remoção das entidades: geração não-controlável, estação de bombeamento e contratos de energia. Não quero manter legado dentro do código, a ideia é realmente remover completamente essas entidades como se nunca houvessem sido programadas anteriormente. Ou seja, é necessário remover os elementos, seus schemas de configuração e seus testes. Quero que você crie o plano se atentando exclusivamente ao que foi especificado, que é a remoção das entidades mencionadas, não expanda o escopo, não complique o plano. É uma atividade simples. Volto a repetir: a remoção dessas entidades deve ser dada de tal forma que pareça que elas nunca existiram no repositório nunca. Especifique que a Branch criada para desenvolver essa funcionalidade deve ser feita a partir da Branch feat/sddp-flexible-lab.

The clarification answers already gathered come from the operator's own message, so they are tagged `source: spec`:

- The scope is exactly the three named entities.
- "Remove completely, as if never programmed" means no deprecation shims, no feature flags, no compatibility paths, no commented-out code and no legacy modules.
- The base branch is `feat/sddp-flexible-lab`.
- The plan stays simple.

---

## (a) Source-tagged requirements

```yaml
requirements:
  - id: R1
    text: "Remove the non-controllable generation entity completely: the NonControllable and NonControllables types (src/System/System.jl), the SystemData.noncontrollables field, get_noncontrollables and get_noncontrollables_entities (src/System/systemdata.jl), its reader, builder and validator code, and every export and re-export (src/System/System.jl, src/SDDPlab.jl). Delete src/System/noncontrollable.jl and src/System/noncontrollable-validators.jl."
    kind: functional
    source: spec
  - id: R2
    text: "Remove the pumping station entity completely: the PumpingStation and PumpingStations types, the SystemData.pumpingstations field, get_pumpingstations and get_pumpingstations_entities, its reader, builder and validator code, and every export and re-export. Delete src/System/pumpingstation.jl and src/System/pumpingstation-validators.jl."
    kind: functional
    source: spec
  - id: R3
    text: "Remove the energy contract entity completely: the EnergyContract and EnergyContracts types, the SystemData.energycontracts field, get_energycontracts and get_energycontracts_entities, its reader, builder and validator code, and every export and re-export. Delete src/System/energycontract.jl and src/System/energycontract-validators.jl."
    kind: functional
    source: spec
  - id: R4
    text: "Remove the configuration schemas of the three entities: NONCONTROLLABLE_SCHEMA, ENERGY_CONTRACT_SCHEMA and PUMPING_STATION_SCHEMA (FieldRule lists built on src/Utils/schema.jl), their key, type, content and consistency validators, and the handling of the optional 'noncontrollables', 'energycontracts' and 'pumpingstations' keys in the build and cast paths of src/System/systemdata-validators.jl."
    kind: functional
    source: spec
  - id: R5
    text: "Remove the tests of the three entities. Delete test/System/test-noncontrollable.jl, test/System/test-pumpingstation.jl and test/System/test-energycontract.jl. In the shared test files (test/Engines/sddp/test-scaling.jl, test/test-load-blocks.jl, test/test-per-stage-blocks.jl), remove the entity fixtures, arguments and locals and keep each testset's purpose unchanged."
    kind: functional
    source: spec
  - id: R6
    text: "Leave no legacy behind. Add no deprecation shims, feature flags, compatibility or migration paths, commented-out code, legacy modules, removal-notice messages, or new tests asserting the entities are absent. Also remove everything whose only consumers were the three entities: parameters, locals, imports and docstring cross-references. A system.jsonc that still carries one of the removed keys is treated like any other unrecognized key today, which the generic reader ignores; no code may handle these keys specifically."
    kind: constraint
    source: spec
  - id: R7
    text: "The scope is only the removal of the three entities. The plan includes no other scope reduction, simplification or refactor; refactoring is limited to what the removal itself makes dead. Systems that do not use these entities behave exactly as before: same LP model, scaling factors and output files."
    kind: constraint
    source: spec
  - id: R8
    text: "Create the feature branch for this work from feat/sddp-flexible-lab."
    kind: constraint
    source: spec
  - id: R9
    text: "Keep the plan in proportion to a simple removal: the fewest epics and tickets that keep each ticket atomic and the package loadable after every ticket, with no speculative or adjacent work."
    kind: constraint
    source: spec
  - id: R10
    text: "Treat the model-level footprint as part of the 'elements' and remove all of it. This covers the LP variables, expressions, load-balance terms, hydro-balance pump terms and objective terms in src/Engines/sddp/build.jl, together with the internal parameters that carry them. It covers the five variable symbols NC_GENERATION, NC_CURTAILMENT, CONTRACT_DISPATCH, PUMPED_FLOW and PUMP_POWER (src/Lab/variables.jl) and their exports (src/Lab/Lab.jl, src/SDDPlab.jl), and their entries in src/Engines/sddp/scaling.jl. It also covers the output files operation_noncontrollables, operation_contracts and operation_pumping (src/Engines/sddp/save_simulation.jl) and validation_operation_noncontrollables, validation_operation_contracts and validation_operation_pumping (src/Engines/sddp/validate.jl)."
    kind: functional
    source: clarification
  - id: R11
    text: "Extend 'as if never existed' to examples and documentation. Delete example/renewable_contracts/, example/pumped_storage/, docs/src/tutorials/renewable_contracts.md, docs/src/tutorials/pumped_storage.md, their two docs/make.jl page entries, and the renewable_contracts and pumped_storage testsets in test/test-examples-tutorial.jl. Remove the entity mentions from the shared docs pages: docs/src/configuration/system.md, docs/src/api/system.md, docs/src/api/variables.md, docs/src/index.md lines 21-22 and docs/src/tutorials/load_blocks.md line 105."
    kind: functional
    source: clarification
  - id: R12
    text: "In CHANGELOG.md v3.0.0, delete the three feature entries (lines 10-12) and the EnergyContract.get_params fix entry (line 37) without adding a 'Removed' note. If R11 is confirmed, change 'Adds five tutorial examples' (line 30) to three."
    kind: constraint
    source: clarification
  - id: R13
    text: "Leave plans/sddp-flexible-lab/** (the completed plan that added the entities) untouched as a historical record. Do not rewrite git history: the work lands as normal commits on a branch created from feat/sddp-flexible-lab."
    kind: constraint
    source: clarification
```

**Requirement count by source:** spec 9 (R1-R9), clarification 4 (R10-R13, confirmed by the operator on 2026-11-10), inferred 0.

### Requirements needing confirmation

All four were presented to the operator on 2026-11-10 and **confirmed** (option A in every case). They are now `source: clarification` and may be cited by `accepted` decisions.

| Id  | Requirement (short)                                                     | Linked question | Status |
| --- | ----------------------------------------------------------------------- | --------------- | ------ |
| R10 | Model-level footprint, including output files, counts as "elements"     | Q3              | Confirmed (A) |
| R11 | Dedicated examples, tutorials and testsets deleted; shared-docs mentions removed | Q1              | Confirmed (A) |
| R12 | CHANGELOG v3.0.0 entries deleted with no "Removed" note                 | Q2              | Confirmed (A) |
| R13 | `plans/sddp-flexible-lab/**` and git history left untouched             | Q2              | Confirmed (A) |

CONFIRMED DECISION (2026-11-10, option A): R10 — Treat the model-level footprint as part of the "elements" and remove it: the LP variables, expressions and terms in `build.jl`; the symbols `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW` and `PUMP_POWER` with their exports; the scaling entries; and the `operation_{noncontrollables,contracts,pumping}` and `validation_operation_{noncontrollables,contracts,pumping}` output files. Confirmed by the operator.

CONFIRMED DECISION (2026-11-10, option A): R11 — Extend "as if never existed" to examples and documentation: delete `example/renewable_contracts/`, `example/pumped_storage/`, both dedicated tutorials, their `docs/make.jl` entries and their two testsets in `test/test-examples-tutorial.jl`, and remove the entity mentions from the shared docs pages (config reference, API reference, variables page, index feature bullet, the `load_blocks` tutorial exercise line). Confirmed by the operator.

CONFIRMED DECISION (2026-11-10, option A): R12 — Delete the CHANGELOG v3.0.0 entries for the three entities (lines 10-12 and 37) without adding a "Removed" note, and correct "five tutorial examples" to three if R11 is confirmed. v3.0.0 is untagged and the entities never reached `main`. Confirmed by the operator.

CONFIRMED DECISION (2026-11-10, option A): R13 — Leave `plans/sddp-flexible-lab/**` untouched as the historical record of the completed plan, and do not rewrite git history; the work lands as normal commits on a branch cut from `feat/sddp-flexible-lab`. Confirmed by the operator.

---

## (b) Domain classification

Step 1 of Domain Decomposition was run against the spec and the verified inventory below.

| Domain | Touched? | What is touched |
| --- | --- | --- |
| **Formulation** (LP model) | Yes, by removal only | The subproblem in `src/Engines/sddp/build.jl`: NC, contract and pump variables and expressions; their load-balance terms; the pump inflow and outflow terms in all three hydro-balance variants; the curtailment and contract objective terms. Scaling in `src/Engines/sddp/scaling.jl` uses NC and contract magnitudes in the shared `max_gen` and `COST_SCALE`. Entity-free systems get an identical LP: the empty collections return early, the objective branches add `0.0`, and the scaling inputs are empty arrays. |
| **Solver integration** | No | No change to the solver lifecycle, warm-start or in-place edits. |
| **Implementation** (language link; this repo is Julia/JuMP, not Rust/C++) | Yes | System data layer (types, `SystemData`, accessors, readers, validators), engine (`build.jl`, `scaling.jl`, `save_simulation.jl`, `validate.jl`), `src/Lab` symbols, exports in `src/SDDPlab.jl`, shared tests |
| **Distribution/MPI** | No | The `SDDP.Threaded()` scheme is unaffected. |
| **I/O** (persisted formats) | Yes, by removal only | Input: three optional `system.jsonc` keys and their CSV/inline schemas. Output: three simulation files and three validation files. Empty outputs are already skipped, so the output set for entity-free cases is unchanged. |
| **Build/deploy** | No | Verified: no references in `build/`, `benchmark/`, `.github/` or `src/precompile_workload.jl`. |
| **Documentation** (from the Consultation Roster) | Yes (Q1 = A) | Dedicated tutorials, `docs/make.jl` pages, config and API reference pages, `index.md`, CHANGELOG |

**Ordered specialist chain** (more than one domain is touched, so a chain is used):

```
sddp-specialist (formulation: confirm the removal leaves an identical LP and scaling for entity-free systems)
  -> hpc-julia-developer (implementation: System layer, schemas/validators, build/scaling/save/validate, Lab symbols, exports, tests)
  -> data-model-format-specialist (I/O: removal of input-schema keys/CSV and output files, no compatibility path)
  -> open-source-documentation-writer (docs/tutorials/CHANGELOG; Q1 = A, Q2 = A)
```

`hpc-julia-developer` implements every code ticket. The I/O link is implemented in the same tickets: the package must load after each ticket, so the code changes for an entity cannot be split by layer. The I/O link takes part as a consultant only.

## (c) Consultant roster

| # | Consultant | Rule that selected it | Narrow focus |
| --- | --- | --- | --- |
| 1 | `sddp-specialist` | Formulation domain touched | Check that removing the terms leaves the LP and scaling unchanged for entity-free systems, and that nothing else in the formulation depended on the entities |
| 2 | `hpc-julia-developer` (dispatched with per-call `model: "opus"` as a consultant) | Implementation domain touched | Order the removal so the package loads after each ticket; list the internal signature and call-site changes |
| 3 | `data-model-format-specialist` | Rule 3: a persisted format is involved (input schema and output files) | Confirm a pure removal with no compatibility path; stale keys are ignored by the generic reader |
| 4 | `open-source-documentation-writer` | Documentation domain touched | Remove the docs mentions so no trace remains (scope depends on Q1/Q2) |

- **`test-strategist` is not added.** Rule 2 adds it only when the plan has two or more epics. R9 points to a single epic. If synthesis produces two or more epics, add it.
- **Cap:** 4 of 6 consultants, so no domain was dropped.
- **Domains not touched:** solver integration, distribution/MPI, build/deploy.
- **Override applied (2026-11-10):** the operator chose to reduce the council, equivalent to `--council=hpc-julia-developer,sddp-specialist`. The roster carried into P2 (briefs) and P3 (sign-off) is therefore:

  | # | Consultant | Domain |
  | --- | --- | --- |
  | 1 | `hpc-julia-developer` (per-call `model: "opus"`) | Julia / JuMP / scientific |
  | 2 | `sddp-specialist` | SDDP / stochastic optimization |

  `data-model-format-specialist` and `open-source-documentation-writer` were dropped by operator decision: the I/O and documentation links are pure removals, implemented inside the same tickets.

## (d) Clarification questions

These come from the Ambiguity Detection Checklist; the full walk is below. There are three questions, and each one settled the linked decision lines above (all confirmed on 2026-11-10).

**Q1 (R11). Does "as if they never existed" also cover the example cases and the documentation?**

> **Answer (2026-11-10): A — yes, all of it.**

- **A. Yes, all of it (recommended).** Delete `example/renewable_contracts/`, `example/pumped_storage/`, both dedicated tutorials, their `docs/make.jl` entries and the two testsets in `test/test-examples-tutorial.jl`. Remove the mentions from the shared docs pages (config reference sections and optional-keys block, `@docs` entries in the API and variables pages, the `index.md` feature bullet, `load_blocks.md:105`).
  - Gain: no trace remains, which matches the spec literally.
  - Cost: a larger diff in docs, and the tutorial count drops from five to three.
- **B. Delete only the dedicated artifacts and leave the shared docs pages.**
  - Cost: the config and API references would still document keys and symbols that no longer exist. Documenter would warn but not fail, because `warnonly = true`, so the site would quietly go stale. This contradicts "never existed".
- **C. Remove only what the spec lists (code, schemas, tests) and leave the examples and docs.**
  - Cost: the two example cases would still run, because their stale keys are ignored, but they would model something other than what their tutorials describe. The docs would describe an API that does not exist.

**Q2 (R12, R13). How should historical records be handled?**

> **Answer (2026-11-10): A — delete the CHANGELOG lines with no "Removed" note, fix the tutorial count, leave `plans/sddp-flexible-lab/**` and git history untouched.**

Facts:
- v3.0.0 is untagged: the latest tag is v2.0.0, locally and on the remote.
- The entities were added in `6525a72` (epic-05) on `feat/sddp-flexible-lab`, which is 45 commits ahead of `main` and has never been merged. No release ever shipped them.

Options:
- **A (recommended).**
  - CHANGELOG: delete lines 10-12 and 37 with no "Removed" note, and fix the "five tutorial examples" count if Q1 is A.
  - `plans/sddp-flexible-lab/**`: leave untouched. It is the execution record of a completed plan, not code.
  - Git history: do not rewrite it.
- **B.** As A, but also add a "Removed" note to the CHANGELOG.
  - Cost: it leaves exactly the trace the spec forbids, and announces the removal of something no release shipped.
- **C.** As A, but also edit or delete the previous plan's tickets 025-027 and other mentions in `plans/sddp-flexible-lab/`.
  - Cost: falsifies a completed plan's record and breaks the consistency of its state file and README with its tickets.
- **D.** As A, but also rewrite the history of `feat/sddp-flexible-lab` (filter-repo or rebase) so the entities never appear.
  - Cost: destructive, requires force-pushing a shared remote branch, and conflicts with "branch from `feat/sddp-flexible-lab`". Out of proportion to "a simple activity".

**Q3 (R10). Confirm that "the elements" includes the entities' footprint in the SDDP model and its outputs.**

> **Answer (2026-11-10): A — yes, remove all of it.**

- **A. Yes, remove all of it (recommended).** This covers the LP terms, the five variable symbols and their exports, the scaling entries, and the six output files. Each item exists only for the three entities. Keeping any of them leaves orphaned symbols, which is the legacy the spec forbids.
- **B. Keep the variable symbols or output-file names as reserved names.**
  - Cost: dead code and a visible trace of the entities.

### Ambiguity Detection Checklist walk

| Item | Status |
| --- | --- |
| User stories | Resolved. Lab researchers; this is the first scope reduction toward a friendlier architecture. |
| Inputs | Resolved. The three optional `system.jsonc` keys and their schemas go away (R4). Stale keys are ignored like any other unknown key (R6), which the reader already does. |
| Outputs | Resolved (Q3 = A): six output files. They are skipped when empty, so entity-free cases keep the same output set (R7). |
| Behavior and edge cases | Resolved. No compatibility path, no removal error (R6). Entity-free systems are unchanged (R7). |
| Scope | Resolved (Q1 = A, Q2 = A): examples, tutorials and shared-docs mentions removed; CHANGELOG lines deleted; `plans/` and git history untouched. |
| Performance, security, accessibility | Not applicable: pure removal, no new surface. |
| APIs | Resolved. The exported Julia API loses the entity types, accessors and symbols (R1-R3, R10). They only ever existed in an untagged version on an unmerged branch, so no version bump is implied. |
| Data flow and state | Resolved. Unchanged for the remaining entities (R7). |

---

## Grounding inventory

Verified on 2026-11-10 with `git grep` over tracked files at HEAD `d16b8ee`. These are facts for synthesis, not decisions.

**Corrections and additions to the dispatch brief:**
- `src/Lab/Lab.jl` exports all five symbols (lines 25-29). The brief did not list this file.
- There are **five** variable symbols: `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW`, `PUMP_POWER`.
- `build.jl` has 65 matching lines once internal plumbing is counted:
  - `add_hydro_balance!`, `add_hydro_balance_parallel!` and `add_hydro_balance_chronological!` take `pump_source_map` and `pump_dest_map`.
  - `__add_load_balance!` takes `noncontrollable_bus_map`, `contract_bus_map`, `contracts_entities`, `pumping_bus_map` and `pumping_entities`.
  - The local `hydro_ids` in `__generate_subproblem_builder` exists only to build the pump maps.
  - The `bus_field` parameter of `_build_bus_index_map` stays live, because lines use `:target_bus_id` and `:source_bus_id`.
- `scaling.jl`:
  - `compute_scaling_factors` feeds NC and contract magnitudes into `all_gen` and `all_costs`.
  - `no_scaling_config` lists `NC_GENERATION`, `CONTRACT_DISPATCH` and `PUMPED_FLOW`.
  - The apply-scaling function rebuilds the three collections (around lines 175-223).
- Output files: `save_simulation.jl` (lines 377-379, 401-405) and `validate.jl` (lines 192-194, 216-220). DataFrames with no rows are skipped, so entity-free cases write no such files today.
- `__validate_keys!` (`src/Utils/validation-utils.jl`) checks only that required keys are present, so removed keys left in a config are ignored silently.
- `test/runtests.jl` discovers test files automatically (`__list_test_files(".")`), so deleting test files needs no change to the runner.
- Shared tests build `SystemData` positionally with seven arguments: `test-scaling.jl` four times, plus `test-load-blocks.jl:88-92` and `test-per-stage-blocks.jl:54-58`. They pass empty pump maps to the hydro-balance helpers in five testsets of `test-load-blocks.jl`, and declare entity-only locals at `test-load-blocks.jl:351-354`.
- Docs:
  - `docs/make.jl` uses `checkdocs = :exports` and `warnonly = true`.
  - `docs/src/configuration/system.md` has the optional-keys block at lines 17-20, three sections at lines 226-438, and the complete example from line 439.
  - `docs/src/tutorials/load_blocks.md:105` and `docs/src/index.md:21-22` mention the entities.
  - `CHANGELOG.md:30` says "five tutorial examples".
- No references in: root `README.md`, `build/`, `benchmark/`, `.github/`, `src/precompile_workload.jl`, `src/Scenarios`, `src/StochasticProcess`, `src/Experiments`.
- `example/*/data/` is gitignored, but the example data files are tracked, so deleting them is a normal tracked deletion (`git rm -r`).

**Dedicated files.** The six `src/System/*` entity files, the three `test/System/test-*` entity files and the two tutorials total 1,576 lines. The two example directories are also dedicated.

**Files that need edits:**
- `src/System/System.jl`, `src/System/systemdata.jl`, `src/System/systemdata-validators.jl`
- `src/SDDPlab.jl` (two export blocks, around lines 32-36 and 89-109, and again around lines 248-252 and 291-313)
- `src/Lab/Lab.jl`, `src/Lab/variables.jl`
- `src/Engines/sddp/{build,scaling,save_simulation,validate}.jl`
- `test/Engines/sddp/test-scaling.jl`, `test/test-load-blocks.jl`, `test/test-per-stage-blocks.jl`, `test/test-examples-tutorial.jl`
- The docs files listed under Q1, and `CHANGELOG.md`

**Suggested final check for synthesis.** A case-insensitive `git grep` over tracked files outside `plans/` should return no hits for:

```
noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage
```

`LICENSE` contains the word "contract" in its legal text and is out of scope.
