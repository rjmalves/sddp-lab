---
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
decisions:
  - id: ADR-001
    title: "Cut the removal into one epic of three tickets, consumers first: model footprint, then System data layer, then examples/docs/CHANGELOG"
    status: accepted
    requirements: [R9, R10, R1, R2, R3, R4, R5, R11, R12]
    options:
      - name: "Two tickets: all Julia code and tests in one ticket, then examples/docs/CHANGELOG (council simplestViable)"
        complexity: low
        durability: "End state identical, no rework. The code ticket spans 23 files and about 50 discrete edits plus a full verification pass, beyond the /plan ~30-minute agent-time gate, and mixes the LP-affecting diff with LP-neutral data-layer deletion in one review."
      - name: "Four tickets: one end-to-end ticket per entity, then examples/docs/CHANGELOG (council mostDurable)"
        complexity: medium
        durability: "End state identical. SystemData arity is edited three times (7 to 6 to 5 to 4), __add_load_balance! three times and the shared tests in every ticket; the only gain is per-entity revert granularity for a reinstatement no requirement states."
      - name: "Three tickets cut consumers-first: model footprint (ticket-001), System data layer (ticket-002), examples/docs/CHANGELOG (ticket-003)"
        complexity: low
        durability: "End state identical, no rework: no line is edited twice (scaling.jl, SDDPlab.jl and test-load-blocks.jl are touched by ticket-001 and ticket-002 in disjoint regions). One transient branch-local commit exists in which the three config keys are still parsed but no longer modeled."
    chosen: "Three tickets cut consumers-first: model footprint (ticket-001), System data layer (ticket-002), examples/docs/CHANGELOG (ticket-003)"
    reversibility: two-way
    rework_trigger: "none known"
  - id: ADR-002
    title: "Shrink every affected signature by deleting the entity parameters, locals and the three SystemData fields outright (positional arity 7 to 4)"
    status: accepted
    requirements: [R1, R2, R3, R6, R7, R10]
    options:
      - name: "Delete the parameters, locals and fields outright; SystemData keeps its positional constructor with 4 arguments"
        complexity: low
        durability: "None known: the exported API never shipped (v3.0.0 is untagged, the branch is unmerged); re-adding an entity later is new work, not a redo of this one."
      - name: "Keep the signatures and fields, passing empty collections or defaulted arguments"
        complexity: low
        durability: "Leaves entity-shaped parameters and fields with no producer, which is exactly the legacy R6 forbids; any later reader would have to delete them."
      - name: "Replace the positional SystemData constructor with a keyword constructor while removing the fields"
        complexity: medium
        durability: "An adjacent refactor R7 forbids; it touches every remaining SystemData call site for a benefit no stated requirement asks for."
    chosen: "Delete the parameters, locals and fields outright; SystemData keeps its positional constructor with 4 arguments"
    reversibility: one-way
    rework_trigger: "none known"
    council:
      recommended_by: [hpc-julia-developer, sddp-specialist]
      objected_by: []
  - id: ADR-003
    title: "Verify R7 with the existing suite plus a one-off, uncommitted before/after dump of every node subproblem and of the ScalingConfig factors"
    status: superseded
    requirements: [R7, R6, R9]
    options:
      - name: "Existing test suite only, with no dump"
        complexity: low
        durability: "The suite fixtures already use empty entity collections, but no test compares whole subproblems; a silent coefficient change in a retained row could pass unnoticed."
      - name: "Existing suite plus a one-off uncommitted before/after dump of every node subproblem and the ScalingConfig factors on five remaining examples, run inside ticket-001"
        complexity: low
        durability: "None inside this plan; it leaves no committed artifact to maintain."
      - name: "Committed golden-LP regression harness with subproblem fingerprints and a seeded serial bound trajectory (council sddp-specialist mostDurable)"
        complexity: high
        durability: "Brittle across JuMP, MOI and HiGHS upgrades and must be maintained on every intended formulation change; it breaches R6 (no new tests about the removal) and R9."
    chosen: "Existing suite plus a one-off uncommitted before/after dump of every node subproblem and the ScalingConfig factors on five remaining examples, run inside ticket-001"
    reversibility: two-way
    rework_trigger: "When a later scope-reduction plan needs repeatable LP-identity evidence across several tickets, that plan adds a committed harness; nothing in this plan is redone."
    council:
      recommended_by: [sddp-specialist, hpc-julia-developer]
      objected_by: []
  - id: ADR-004
    title: "Develop on a new branch feat/remove-system-entities created from feat/sddp-flexible-lab, with normal commits and no history rewrite"
    status: accepted
    requirements: [R8, R13]
    options:
      - name: "New branch feat/remove-system-entities created from feat/sddp-flexible-lab; normal commits; plans/sddp-flexible-lab untouched"
        complexity: low
        durability: "None known."
      - name: "Commit directly on feat/sddp-flexible-lab"
        complexity: low
        durability: "Contradicts R8 and removes the isolated review and merge unit for the removal."
      - name: "Rewrite the history of feat/sddp-flexible-lab (filter-repo or rebase) so the entities never appear"
        complexity: high
        durability: "Destructive force-push of a shared remote branch; rejected by R13."
    chosen: "New branch feat/remove-system-entities created from feat/sddp-flexible-lab; normal commits; plans/sddp-flexible-lab untouched"
    reversibility: two-way
    rework_trigger: "none known"
  - id: ADR-005
    title: "Verify R7 with the existing suite plus a one-off, uncommitted dump of parameterized node subproblems and ScalingConfig factors under NoScaling and AutoScaling, a perturbed compute_scaling_factors case, and a mandatory rerun after ticket-002"
    status: accepted
    supersedes: ADR-003
    requirements: [R7, R6, R9]
    options:
      - name: "NoScaling-only dump of every unparameterized node subproblem and of the ScalingConfig factors, run inside ticket-001 (ADR-003 as accepted at synthesis)"
        complexity: low
        durability: "Blind to what this plan edits by hand. The written LPs carry no objective vector c, because SDDP.jl installs the stage objective only in parameterize. No example sets scaling, so compute_scaling_factors and apply_scaling never run and every dumped factor is 1.0. A broken objective edit (build.jl:435-453), a mis-deleted splat next to scaling.jl:35 or :73, or a broken apply_scaling rewrite passes every gate."
      - name: "Existing suite plus a one-off uncommitted dump of every parameterized node subproblem and the ScalingConfig factors of five remaining examples under NoScaling and AutoScaling, plus a perturbed compute_scaling_factors case, taken at the base commit, after ticket-001 and (mandatory) after ticket-002"
        complexity: low
        durability: "None inside this plan. Nothing is committed; the dump script is arity-agnostic, so it runs unchanged on the 7-field and the 4-field SystemData; a byte mismatch is re-read through MOI and compared within 4 ULP per coefficient before it counts as an R7 violation, because signed zeros and number formatting can change bytes without changing a value."
      - name: "Committed golden-LP regression harness with subproblem fingerprints and a seeded serial bound trajectory (council sddp-specialist mostDurable)"
        complexity: high
        durability: "Brittle across JuMP, MOI and HiGHS upgrades and must be maintained on every intended formulation change; it breaches R6 (no new tests about the removal) and R9."
    chosen: "Existing suite plus a one-off uncommitted dump of every parameterized node subproblem and the ScalingConfig factors of five remaining examples under NoScaling and AutoScaling, plus a perturbed compute_scaling_factors case, taken at the base commit, after ticket-001 and (mandatory) after ticket-002"
    reversibility: two-way
    rework_trigger: "When a later scope-reduction plan needs repeatable LP-identity evidence across several tickets, that plan adds a committed harness; nothing in this plan is redone."
    council:
      recommended_by: [sddp-specialist]
      objected_by: []
---

# Master Plan: Remove System Entities

## Executive Summary

SDDPlab is a laboratory for prospecting new SDDP methodologies, and the operator is reducing its scope toward a friendlier architecture. This first reduction removes three system entities completely: non-controllable generation, pumping stations and energy contracts. "Completely" means as if they had never been programmed: their types, schemas, validators, LP footprint, variable symbols, output files, tests, examples, tutorials, documentation mentions and CHANGELOG entries all go, with no shim, flag, compatibility path or removal notice.

The plan is one epic of three deletion-only tickets, executed in order on a new branch `feat/remove-system-entities` created from `feat/sddp-flexible-lab`. The package loads and `Pkg.test()` passes after every ticket, and systems that never used the entities build the same LP under both scaling modes (ADR-005).

## Development Branch (R8, ADR-004)

The development branch MUST be created from `feat/sddp-flexible-lab`, not from `main`:

```bash
git switch feat/sddp-flexible-lab
git switch -c feat/remove-system-entities feat/sddp-flexible-lab
```

All three tickets land as normal commits on `feat/remove-system-entities`. No history is rewritten, and `plans/sddp-flexible-lab/**` is not touched (R13). ticket-001 performs the branch creation as its first precondition; ticket-002 and ticket-003 verify they run on that branch.

## Goals & Non-Goals

### Goals

- Remove the three entities from the Julia package: types, collections, `SystemData` fields, accessors, readers, schemas, validators, exports (R1-R4).
- Remove their model-level footprint: LP variables, expressions and terms in `build.jl`, the five Lab symbols, the scaling entries, the unscale-factor branches and the six output files (R10).
- Remove their tests and the entity fixtures in shared tests, keeping each retained testset's purpose (R5).
- Remove the dedicated examples and tutorials, the entity mentions in shared docs pages and the v3.0.0 CHANGELOG entries (R11, R12).
- Leave no legacy: nothing whose only consumers were the entities survives (R6).
- Keep entity-free systems unchanged: same LP model, same values for every retained scaling factor, same output files (R7).

### Non-Goals

- Any other scope reduction, simplification or refactor (R7). In particular: no keyword constructor for `SystemData`, no change to the abstract `Integer`/`Real` fields of the remaining entities, no rename of `_build_bus_index_map`, no cleanup of the pre-existing unused `line_target_map`/`line_source_map` locals in `test/test-load-blocks.jl`.
- A committed LP-identity regression harness or any new test asserting the entities are absent (R6, ADR-005).
- Any handling of stale `noncontrollables`/`energycontracts`/`pumpingstations` keys in an old `system.jsonc`: the generic reader already ignores unknown keys (R6).
- Edits to `plans/sddp-flexible-lab/**`, to git history, to `LICENSE` (its legal text contains the word "contract"), or a version bump (R13).

## Architecture Overview

### Current State

At HEAD `d16b8ee` the three entities run through every layer of the package:

| Layer | Files | Entity footprint |
| --- | --- | --- |
| System data | `src/System/System.jl`, `systemdata.jl`, `systemdata-validators.jl`, six dedicated `src/System/{noncontrollable,energycontract,pumpingstation}{,-validators}.jl` | 6 types, 3 `SystemData` fields (positional arity 7), 6 accessors, 3 schemas, optional-key build and cast branches |
| Lab symbols | `src/Lab/variables.jl`, `src/Lab/Lab.jl`, `src/SDDPlab.jl` | `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW`, `PUMP_POWER` and their exports; 6 types and 6 accessors re-exported |
| Engine (LP) | `src/Engines/sddp/build.jl` | 3 `add_system_elements!` methods; pump terms in all three hydro-balance functions; NC, contract and pump terms in `__add_load_balance!`; curtailment and contract objective branches; 9 builder locals |
| Engine (scaling) | `src/Engines/sddp/scaling.jl` | NC/contract inputs to `all_gen`/`all_costs`; 3 factor keys in `compute_scaling_factors` and `no_scaling_config`; 3 collection rebuilds in `apply_scaling` |
| Engine (outputs) | `src/Engines/sddp/save_simulation.jl`, `validate.jl` | unscale-factor branches (lines 65-72); `operation_*` and `validation_operation_*` files for the three entities |
| Tests | 3 dedicated `test/System/test-*.jl`; `test/Engines/sddp/test-scaling.jl`, `test/test-load-blocks.jl`, `test/test-per-stage-blocks.jl`, `test/test-examples-tutorial.jl` | dedicated tests; 7-argument `SystemData` fixtures; empty pump maps; 2 example testsets |
| Examples, docs | `example/{renewable_contracts,pumped_storage}/` (23 files), 2 tutorials, `docs/make.jl`, 5 shared docs pages, `CHANGELOG.md` | dedicated material and mentions |

### Target State

The package contains four system entities (buses, lines, hydros, thermals). `SystemData(buses, lines, hydros, thermals)` is the only constructor shape. The LP, the scaling factors and the output files for any system are exactly what an entity-free system produces today. No file outside `plans/` and `LICENSE` matches the final grep gate below.

### Key Design Decisions

The frontmatter `decisions:` block is authoritative; this section explains it.

- **ADR-001 — Three tickets, consumers first.** Both council briefs recommended two tickets, arguing the code cannot be split by layer because Julia resolves signature type annotations at load time and `SystemData`'s positional arity is shared by `apply_scaling` and six test fixtures. Both constraints hold, but they only forbid deleting a type *before* its consumers, or changing the arity in a ticket that does not also update every positional call site. The consumers-first cut honours both: ticket-001 removes every engine-side reader of the entity data except the `apply_scaling` rebuild (which only uses field access, `system.noncontrollables.entities`, never the accessors), so the six types and the 7-field `SystemData` stay intact and the package loads; ticket-002 then deletes the types, the fields and the arity together with `apply_scaling`'s rebuild and all six test fixtures. No `System`-layer file references the five Lab symbols, so removing the symbols in ticket-001 cannot break the `System` layer at call time. The cut was chosen over the two-ticket option because the single code ticket (23 files, about 50 discrete edits) exceeds the /plan ~30-minute agent-time gate, which makes the three-ticket cut the fewest tickets that keep each one atomic (R9). It also isolates the whole LP-affecting diff in ticket-001, where the R7 identity check runs, while ticket-002 is LP-neutral by construction (it deletes only data nothing in the model reads after ticket-001); ADR-005's mandatory rerun after ticket-002 checks that claim instead of assuming it. The cost is one more ticket and one transient branch-local commit in which the three keys are still parsed and validated but no longer modeled; the end-state code is identical under every option, so this is a two-way door. The per-entity option was rejected: it edits the arity and `__add_load_balance!` three times for a revert granularity no requirement asks for. The two example testsets in `test/test-examples-tutorial.jl` move with ticket-002 so that `src/` and `test/` are clean after it; the example directories they exercised go in ticket-003 (the examples still run after ticket-002 because stale keys are ignored).
- **ADR-002 — Delete parameters and fields outright.** Every function that carried entity data loses those parameters, and `SystemData` goes from 7 to 4 positional fields. Keeping the parameters with empty defaults is legacy (R6); switching to a keyword constructor is an adjacent refactor (R7). This is the plan's one-way door (exported API), accepted with no deprecation path because the API never shipped.
- **ADR-003 — R7 verification (superseded by ADR-005).** Kept as the record of the synthesis-time choice: the existing suite as the oracle plus a one-off, uncommitted before/after dump of every node subproblem and of the factors, inside ticket-001. The sign-off review and design-critique round 1 showed that this dump could not see either part of the model the plan edits by hand, so ADR-005 replaces its procedure while keeping its option class.
- **ADR-005 — R7 verification, amended (supersedes ADR-003).** The option class is unchanged: the existing suite stays the oracle, no retained numeric expectation may be edited, and the LP-identity evidence is a one-off, uncommitted dump with no committed harness (R6, R9). The procedure changes in five places, because the ADR-003 dump was blind to what this plan edits by hand:
  - (a) Every node is parameterized with its first noise term, `SDDP.parameterize(node, first(node.noise_terms).term)`, before `SDDP.write_subproblem_to_file`. SDDP.jl installs the stage objective plus `theta` into the JuMP model only inside `parameterize`, so without this step every file minimizes 0 and the curtailment and contract objective edit (`build.jl:435-453`) goes unchecked. This is the accepted `sddp-specialist` sign-off objection. Parameterizing is deterministic, because the SAA is seeded through `generate_saa(..., scenarios.seed)` and all five examples set `seed`.
  - (b) None of the five examples sets `scaling`, so the engine defaults to `NoScaling`, and neither `compute_scaling_factors` (edited in ticket-001) nor `apply_scaling` (rewritten in ticket-002) ever ran in the dump. Each example is therefore dumped a second time with the policy's scaling replaced by `Engines.AutoScaling()`, using the `SDDPlab.Study(original.inputs, engine)` pattern of `test/test-main.jl:436-457`. Those subproblems and their non-identity factors go to an `autoscale/` subtree (critique F1-001).
  - (c) No example has a thermal cost above its deficit cost. The script therefore also calls `compute_scaling_factors` on an in-memory `4ree` variant whose first thermal gets twice the largest hydro `max_generation` and twice the largest deficit cost; its lines are non-empty. It asserts that both values reach the factors and dumps the sorted factors to `perturbed/`. This exercises the thermal splats at `scaling.jl:35` and `:73`, next to the lines ticket-001 deletes (F1-001).
  - (d) The rerun after ticket-002 against the saved base dump is mandatory. ticket-002 carries it as an acceptance criterion and fences `src/Engines/sddp/scaling.jl` in `hpcFencedPaths`, like ticket-001 (F1-001 and the sign-off note).
  - (e) A subproblem file that is not byte-identical is re-read through MOI and compared coefficient by coefficient within 4 ULP before it counts as an R7 violation, because signed zeros and number formatting can change bytes without changing a value. A real difference is escalated with the diff and never patched. Factor values are compared exactly, because `repr(::Float64)` round-trips.

  Between ticket-001 and ticket-002, the script, the comparison helper, a copy of `Manifest.toml` and the base dump stay outside the repository in `/tmp/sddplab-r7`. If they are missing, or the environment changed, ticket-002 regenerates the base dump from a detached worktree of the base commit. This is a two-way door, because nothing is committed.
- **ADR-004 — Branch.** A new branch cut from `feat/sddp-flexible-lab`, normal commits, no history rewrite (R8, R13).

## Technical Approach

### Tech Stack

Julia 1.10 (CI also runs `1`), JuMP, SDDP.jl, HiGHS, Documenter.jl for the docs site, JuliaFormatter v1 in Blue style (`.JuliaFormatter.toml`; CI's `format_check.yml` formats `src`, `test` and `docs` and fails on any diff).

### Specialist Chain

The feature touches formulation, implementation, I/O (input keys and output files) and documentation, so it uses an ordered chain rather than a single agent:

```
sddp-specialist (formulation: LP and scaling invariance contract for entity-free systems; ADR-005)
  -> hpc-julia-developer (implementation: ticket-001 model footprint, ticket-002 System layer, ticket-003 examples/docs/CHANGELOG)
```

The I/O link (input-schema keys, output files) and the documentation link are pure removals implemented inside the same tickets; by operator decision (2026-11-10) the council roster was reduced to `hpc-julia-developer` and `sddp-specialist`, so `data-model-format-specialist` and `open-source-documentation-writer` do not take part. `hpc-julia-developer` implements all three tickets: ticket-003's only authored text is verbatim in the ticket, and its gates (docs build, formatter, `Pkg.test()`) are Julia commands.

### Component/Module Breakdown

| Ticket | Removes | Modules touched |
| --- | --- | --- |
| ticket-001 | LP footprint, 5 Lab symbols and exports, scaling inputs and keys, unscale branches, 6 output files, pump maps and load-balance locals in `test/test-load-blocks.jl` | `Lab`, `Engines`, `SDDPlab` |
| ticket-002 | 6 dedicated System files, 6 types, 3 `SystemData` fields, 6 accessors, optional-key branches, re-exports, `apply_scaling` rebuild, 3 dedicated tests, 7-argument fixtures, 2 example testsets | `System`, `Engines` (`apply_scaling` only), `SDDPlab`, tests |
| ticket-003 | 2 example directories, 2 tutorials, 2 `docs/make.jl` entries, shared-docs mentions, CHANGELOG entries | `example/`, `docs/`, `CHANGELOG.md` |

### Chain Contracts

**Signatures after removal** (from the `hpc-julia-developer` brief, confirmed against HEAD):

```julia
SystemData(buses::Buses, lines::Lines, hydros::Hydros, thermals::Thermals)          # ticket-002
add_hydro_balance!(m::JuMP.Model, hydros::Hydros, block_mode::Symbol,
                   tau_k::Vector{Float64}, num_blocks::Int)                          # ticket-001
add_hydro_balance_parallel!(m::JuMP.Model, hydros::Hydros, zeta::Float64,
                            w_k::Vector{Float64}, num_blocks::Int)                   # ticket-001
add_hydro_balance_chronological!(m::JuMP.Model, hydros::Hydros, zeta_k::Vector{Float64},
                                 w_k::Vector{Float64}, num_blocks::Int)              # ticket-001
__add_load_balance!(m::JuMP.Model, scenarios::ScenariosData, node::Integer, load_scale::Float64,
                    bus_ids::Vector{<:Integer}, num_blocks::Int,
                    hydro_bus_map::Dict{Int,Vector{Int}}, thermal_bus_map::Dict{Int,Vector{Int}},
                    line_target_map::Dict{Int,Vector{Int}}, line_source_map::Dict{Int,Vector{Int}})  # ticket-001
_build_bus_index_map(entities::AbstractVector, bus_ids::Vector{<:Integer}, bus_field::Symbol)  # unchanged
```

`add_system_elements!(m, s::SystemData, num_blocks)` dispatches to `Buses`, `Lines`, `Thermals` and `Hydros` only, in that order. `_net_flow_expr` in the chronological variant returns `upstream_flow - m[OUTFLOW][n, k]`.

**LP and scaling invariance** (from the `sddp-specialist` brief): for a system with no entities, every removed term is an empty sum or `tau_k[k] * 0.0`, and the removed `add_system_elements!` methods returned before creating any column, so every node subproblem keeps identical `(c, A, b, l, u)` and row/column order. `max_gen` and `max_cost` lose only empty splats. The removed factor keys copied retained values (`NC_GENERATION`, `CONTRACT_DISPATCH` copy `HYDRO_GENERATION`; `PUMPED_FLOW` copies `STORED_VOLUME`), so `_is_identity_scaling` is unchanged; the only visible effect is three fewer entries in the `@info "AutoScaling applied"` log line, which is not persisted. The state space (`STORED_VOLUME`, `STCHP`), the cut dimension and the cut-file format are unchanged.

**Per-ticket gate** (Julia resolves global names inside function bodies only at call time, so a successful `using SDDPlab` is not proof of a clean removal):

| Gate | ticket-001 | ticket-002 | ticket-003 |
| --- | --- | --- | --- |
| Grep | symbol and plumbing pattern over `src/` and `test/` exits 1; entity types and accessors absent from `src/Engines` except inside `apply_scaling` | extended pattern over `src/` and `test/` exits 1 | extended pattern over the whole repo excluding `plans/` and `LICENSE` exits 1 |
| `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` | exit 0, no `@test` line changed | exit 0, no `@test` line changed in shared tests | exit 0 |
| JuliaFormatter v1 fixpoint over `src`, `test`, `docs` | exit 0 | exit 0 | exit 0 |
| Extra | R7 dump at the base commit and after the edits: parameterized subproblems and factors under `NoScaling` and `AutoScaling`, plus the perturbed `compute_scaling_factors` case (ADR-005) | `fieldnames(SystemData)` is the 4-tuple; a stale-key `system.jsonc` reads with zero errors (R6); mandatory R7 rerun of the same dump against ticket-001's base dump (ADR-005) | docs build exits 0 with no entity name in its log; `plans/sddp-flexible-lab` unchanged |

### Final Whole-Repo Grep Gate

The intake pattern extended with the internal plumbing names the briefs found (`pump_source_map`, `pump_dest_map`, `contract_bus_map`, `pumping_bus_map`, `nc_bus_map`, `num_nc`, `num_contracts`, `source_pump`, `dest_pump`, all caught by `pump|contract|curtail|\bnc_|num_nc`). Verified at HEAD: every hit outside `plans/` and `LICENSE` lies in a line or file this plan removes, so the pattern has no false positive on surviving content.

```bash
git grep -n -i -E 'noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc' -- . ':!plans/' ':!LICENSE'
# required: no output, exit status 1
```

`hydro_ids` is deliberately not in the pattern: it is legitimately used in `src/System/hydro-validators.jl`; ticket-001 removes only the dead `build.jl` local of that name.

### Data Flow

Unchanged for the four remaining entities: `system.jsonc` -> `__cast_system_internals_from_files!` -> `SystemData` -> `apply_scaling` -> `__generate_subproblem_builder` -> SDDP subproblems -> simulation -> `save_simulation`/`validate` writers. Stale entity keys in an old `system.jsonc` are never read, because `__validate_keys!` only checks that the four required keys are present.

### Testing Strategy

No test is added (R6). The existing suite (`test/runtests.jl` auto-discovers files, so deleting dedicated tests needs no runner change) is the oracle; any failure of a retained numeric expectation is an R7 violation to escalate, never an expectation to edit. The existing suite does not cover what the removal edits by hand: no test asserts an SDDPlab stage objective, every scaling fixture has deficit cost above thermal cost and empty lines, and the AutoScaling end-to-end test compares only the unit-invariant unscaled bound. The one-off R7 dump of ADR-005 closes that gap without committing anything. ticket-001 takes the dump at the base commit and after its edits, and ticket-002 reruns it against the same base dump. Each run covers the parameterized node subproblems and the `ScalingConfig` factors of `1dtoy`, `1dtoy_per_stage_blocks`, `load_blocks`, `4ree` and `markov_var` under the engine's `NoScaling` and under `AutoScaling`, plus the perturbed `compute_scaling_factors` case. A single epic means `test-strategist` is not on the roster.

## Phases & Milestones

| Order | Ticket | Milestone |
| --- | --- | --- |
| 1 | ticket-001-remove-entity-model-footprint.md | Branch created; LP, Lab symbols, scaling keys and output files free of the entities; R7 identity evidence captured under both scaling modes |
| 2 | ticket-002-remove-entity-system-layer.md | `src/` and `test/` free of every entity trace; `SystemData` has 4 fields; R7 identity re-verified against the base dump |
| 3 | ticket-003-remove-entity-traces-outside-package.md | Whole repo (outside `plans/` and `LICENSE`) passes the final grep gate; docs build clean |

## Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| A function body still references a removed symbol (load succeeds, call fails) | Medium | High | Per-ticket grep gates; full `Pkg.test()`; `test-scaling.jl` already calls `_get_variable_unscale_factor(:MARGINAL_COST, ...)`, which walks past the removed `elseif` chain |
| The removal changes the LP or the scaling factors of an entity-free system, including through the objective edit in `build.jl`, a mis-deleted splat in `compute_scaling_factors` or the `apply_scaling` rewrite | Low | High | ADR-005 dump at the base commit, after ticket-001 and after ticket-002. It covers parameterized subproblems (with `c`) and factors under `NoScaling` and `AutoScaling`, plus a perturbed case in which thermal cost and thermal `max_generation` dominate. A file that is not byte-identical is re-read through MOI and compared within 4 ULP; a real difference is escalated with the diff, never patched |
| Formatter reflow of shortened signatures fails CI `format_check.yml` | High | Low | Formatter fixpoint is an acceptance criterion of every ticket |
| Formatter touches files outside a ticket's scope (pre-existing drift) | Low | Medium | `git status --porcelain` check; out-of-scope reformatting is escalated, not committed |
| A cut file trained with one of the removed entities is loaded into the reduced model | Negligible | Medium | Accepted non-guarantee (sddp-specialist brief): such policies exist only on the untagged, unmerged branch, and R6 forbids a guard |
| Transient commit after ticket-001 parses but ignores the three keys | Certain (transient) | Negligible | Branch-local only; ticket-002 removes the reader paths; the plan merges as one branch |

## Success Metrics

- The final whole-repo grep gate prints nothing and exits 1.
- `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` exits 0 after every ticket.
- The R7 dump, taken after ticket-001 and again after ticket-002, shows parameterized subproblems identical to the base commit for `1dtoy`, `1dtoy_per_stage_blocks`, `load_blocks`, `4ree` and `markov_var`, under both the engine's `NoScaling` and `AutoScaling`. Identical means byte-identical, or within 4 ULP per coefficient when read back through MOI. The factor files differ only by the three removed keys: the `NoScaling` and `AutoScaling` files of each example and the file of the perturbed `compute_scaling_factors` case.
- `julia --project=docs/ docs/make.jl` exits 0 with no entity name in its log.
- `git diff --quiet $(git merge-base HEAD feat/sddp-flexible-lab) -- plans/sddp-flexible-lab` exits 0.
- The plan adds zero files under `src/`, `test/`, `example/` or `docs/`.
